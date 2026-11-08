//! Background heartbeat worker for a registered FEAGI session.
//!
//! FEAGI deregisters any agent that stays quiet past its liveness timeout, so a registered
//! session must keep talking. The worker owns the registered command/control link and runs one
//! non-blocking loop:
//!
//! - exactly one heartbeat is in flight: send, then wait for the `HeartBeat` ack before the next
//!   send;
//! - an interval that passes without the ack counts as one missed ack; `max_missed_acks`
//!   consecutive misses, a transport error, or a server-side deregistration mark the session
//!   dead (FEAGI silently drops traffic from an agent it no longer knows, so a missing ack is
//!   how that case shows up);
//! - a stop flag is checked on every pass, and the sleep step is a fraction of the interval.
//!
//! The loop never panics: `panic = "abort"` in the release profile would take Godot down with it.
//! The transport is reached through [`SessionLink`], so the loop is unit-tested without sockets.

use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

/// Number of worker passes per heartbeat interval. The sleep step is `interval / this`, so every
/// wait in the worker (stop latency, ack latency, join bound) scales with the configured interval.
pub const POLL_STEPS_PER_INTERVAL: u32 = 20;

/// Deregistration outcome slot: no answer yet.
const DEREG_PENDING: u8 = 0;
/// Deregistration outcome slot: FEAGI confirmed the deregistration.
const DEREG_SUCCEEDED: u8 = 1;
/// Deregistration outcome slot: the request failed or was not answered in time.
const DEREG_FAILED: u8 = 2;

/// Validated heartbeat timing. Both values come from BV config; there are no defaults.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HeartbeatConfig {
    interval: Duration,
    max_missed_acks: u64,
}

impl HeartbeatConfig {
    /// Validate the two settings. Both must be strictly positive and the interval must be a
    /// finite duration that still yields a non-zero worker step.
    pub fn new(interval_s: f64, max_missed_acks: i64) -> Result<Self, String> {
        if !(interval_s.is_finite() && interval_s > 0.0) {
            return Err(format!(
                "heartbeat_interval_s must be a finite number > 0, got {interval_s}"
            ));
        }
        if max_missed_acks <= 0 {
            return Err(format!(
                "max_missed_heartbeat_acks must be > 0, got {max_missed_acks}"
            ));
        }
        let interval = Duration::try_from_secs_f64(interval_s)
            .map_err(|e| format!("heartbeat_interval_s is out of range: {e}"))?;
        if (interval / POLL_STEPS_PER_INTERVAL).is_zero() {
            return Err(format!(
                "heartbeat_interval_s {interval_s} is too small to derive a worker step"
            ));
        }
        let max_missed_acks = u64::try_from(max_missed_acks)
            .map_err(|e| format!("max_missed_heartbeat_acks is out of range: {e}"))?;
        Ok(Self {
            interval,
            max_missed_acks,
        })
    }

    /// Time between heartbeats, and the length of one missed-ack interval.
    pub fn interval(&self) -> Duration {
        self.interval
    }

    /// Consecutive missed-ack intervals after which the session is marked dead.
    pub fn max_missed_acks(&self) -> u64 {
        self.max_missed_acks
    }

    /// Sleep step of the worker loop, derived from the interval.
    pub fn poll_step(&self) -> Duration {
        self.interval / POLL_STEPS_PER_INTERVAL
    }
}

/// What one non-blocking poll of the command/control link produced.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LinkEvent {
    /// Nothing arrived.
    Idle,
    /// FEAGI acknowledged a heartbeat.
    HeartbeatAck,
    /// FEAGI answered a deregistration request.
    Deregistered,
    /// Some other message arrived; the worker ignores it.
    Other,
}

/// The registered command/control link the worker drives. Implemented over the feagi-agent
/// `CommandControlAgent` in production and over a scripted fake in unit tests.
pub trait SessionLink {
    /// Non-blocking poll for one inbound message.
    fn poll(&mut self) -> Result<LinkEvent, String>;
    /// Send one heartbeat.
    fn send_heartbeat(&mut self) -> Result<(), String>;
    /// Send a deregistration request over this link.
    fn send_deregistration(&mut self) -> Result<(), String>;
    /// Whether the link still considers itself registered.
    fn is_registered(&self) -> bool;
    /// Best-effort socket teardown. Safe to call more than once.
    fn disconnect(&mut self);
}

/// State shared between the worker thread and its owner.
#[derive(Debug, Default)]
pub struct HeartbeatShared {
    stop: AtomicBool,
    alive: AtomicBool,
    dereg_requested: AtomicBool,
    dereg_state: AtomicU8,
    error: Mutex<String>,
}

impl HeartbeatShared {
    /// Fresh state: not alive, no stop, no error.
    pub fn new() -> Self {
        Self::default()
    }

    /// Ask the worker to exit at its next pass.
    pub fn request_stop(&self) {
        self.stop.store(true, Ordering::SeqCst);
    }

    /// Whether a stop was requested.
    pub fn stop_requested(&self) -> bool {
        self.stop.load(Ordering::SeqCst)
    }

    /// Mark the session as registered and heartbeating.
    pub fn mark_alive(&self) {
        self.alive.store(true, Ordering::SeqCst);
    }

    /// Whether the worker is running a live session.
    pub fn is_alive(&self) -> bool {
        self.alive.load(Ordering::SeqCst)
    }

    /// Record the first failure reason and mark the session dead. Later reasons are ignored so
    /// the root cause stays readable.
    pub fn mark_dead(&self, reason: &str) {
        if let Ok(mut slot) = self.error.lock() {
            if slot.is_empty() {
                *slot = reason.to_string();
            }
        }
        self.alive.store(false, Ordering::SeqCst);
    }

    /// The recorded failure reason, empty when the session ended cleanly or is still alive.
    pub fn error(&self) -> String {
        self.error
            .lock()
            .map(|slot| slot.clone())
            .unwrap_or_default()
    }
}

/// Run the heartbeat loop until stop, death or a deregistration request. Marks the session not
/// alive on exit and disconnects the link.
pub fn run_heartbeat_loop<L: SessionLink>(
    link: &mut L,
    config: &HeartbeatConfig,
    shared: &HeartbeatShared,
) {
    let step = config.poll_step();
    let mut last_send = Instant::now();
    // Set while a heartbeat awaits its ack: the start of the current wait interval.
    let mut waiting_since: Option<Instant> = None;
    let mut missed: u64 = 0;

    loop {
        if shared.stop_requested() {
            break;
        }
        if shared.dereg_requested.load(Ordering::SeqCst) {
            run_deregistration(link, config, shared);
            break;
        }

        match link.poll() {
            Err(e) => {
                shared.mark_dead(&format!("heartbeat link error: {e}"));
                break;
            }
            Ok(LinkEvent::HeartbeatAck) => {
                waiting_since = None;
                missed = 0;
            }
            Ok(LinkEvent::Deregistered) => {
                shared.mark_dead("FEAGI deregistered this session");
                break;
            }
            Ok(LinkEvent::Idle | LinkEvent::Other) => {}
        }
        if !link.is_registered() {
            shared.mark_dead("session is no longer registered");
            break;
        }

        let now = Instant::now();
        match waiting_since {
            None => {
                if now.duration_since(last_send) >= config.interval() {
                    if let Err(e) = link.send_heartbeat() {
                        shared.mark_dead(&format!("heartbeat send failed: {e}"));
                        break;
                    }
                    last_send = now;
                    waiting_since = Some(now);
                }
            }
            Some(since) => {
                if now.duration_since(since) >= config.interval() {
                    missed += 1;
                    waiting_since = Some(now);
                    if missed >= config.max_missed_acks() {
                        shared.mark_dead(&format!(
                            "no heartbeat ack for {missed} consecutive intervals"
                        ));
                        break;
                    }
                }
            }
        }
        thread::sleep(step);
    }

    link.disconnect();
    shared.alive.store(false, Ordering::SeqCst);
}

/// Deregister over the live link and publish the outcome. Bounded by one heartbeat interval.
fn run_deregistration<L: SessionLink>(
    link: &mut L,
    config: &HeartbeatConfig,
    shared: &HeartbeatShared,
) {
    if let Err(e) = link.send_deregistration() {
        shared.mark_dead(&format!("deregistration send failed: {e}"));
        shared.dereg_state.store(DEREG_FAILED, Ordering::SeqCst);
        return;
    }
    let deadline = Instant::now() + config.interval();
    while Instant::now() < deadline {
        match link.poll() {
            Ok(LinkEvent::Deregistered) => {
                shared.dereg_state.store(DEREG_SUCCEEDED, Ordering::SeqCst);
                return;
            }
            Err(e) => {
                shared.mark_dead(&format!("deregistration poll failed: {e}"));
                shared.dereg_state.store(DEREG_FAILED, Ordering::SeqCst);
                return;
            }
            Ok(_) => thread::sleep(config.poll_step()),
        }
    }
    shared.mark_dead("deregistration was not answered in time");
    shared.dereg_state.store(DEREG_FAILED, Ordering::SeqCst);
}

/// Owner-side handle of a running heartbeat worker. Dropping it stops the worker the same
/// bounded way [`HeartbeatSession::stop`] does.
pub struct HeartbeatSession {
    shared: Arc<HeartbeatShared>,
    worker: Option<JoinHandle<()>>,
    config: HeartbeatConfig,
    agent_id_b64: String,
}

impl HeartbeatSession {
    /// Wrap a spawned worker and the state it shares with this handle.
    pub fn new(
        shared: Arc<HeartbeatShared>,
        worker: JoinHandle<()>,
        config: HeartbeatConfig,
        agent_id_b64: String,
    ) -> Self {
        Self {
            shared,
            worker: Some(worker),
            config,
            agent_id_b64,
        }
    }

    /// Whether the worker is still heartbeating a live session.
    pub fn is_alive(&self) -> bool {
        self.shared.is_alive()
    }

    /// Why the session died, empty when it is alive or ended cleanly.
    pub fn error(&self) -> String {
        self.shared.error()
    }

    /// The session's agent ID as base64.
    pub fn agent_id_b64(&self) -> &str {
        &self.agent_id_b64
    }

    /// Stop the worker: set the flag, wait up to one heartbeat interval for it to exit, then
    /// detach it. Returns true when the worker exited in time. Safe to call twice.
    pub fn stop(&mut self) -> bool {
        self.shared.request_stop();
        self.join_bounded(self.config.interval())
    }

    /// Deregister over the live session socket and stop the worker. Returns true when FEAGI
    /// confirmed the deregistration. False when the worker is not alive or no confirmation came
    /// within the bound (two heartbeat intervals).
    pub fn deregister(&mut self) -> bool {
        if !self.shared.is_alive() {
            return false;
        }
        self.shared.dereg_requested.store(true, Ordering::SeqCst);
        let deadline = Instant::now() + self.config.interval() * 2;
        while Instant::now() < deadline {
            if self.shared.dereg_state.load(Ordering::SeqCst) != DEREG_PENDING {
                break;
            }
            if self.worker.as_ref().is_none_or(JoinHandle::is_finished) {
                break;
            }
            thread::sleep(self.config.poll_step());
        }
        let confirmed = self.shared.dereg_state.load(Ordering::SeqCst) == DEREG_SUCCEEDED;
        self.stop();
        confirmed
    }

    /// Join the worker if it exits within `bound`; otherwise drop the handle (detach).
    fn join_bounded(&mut self, bound: Duration) -> bool {
        let Some(handle) = self.worker.take() else {
            return true;
        };
        let deadline = Instant::now() + bound;
        loop {
            if handle.is_finished() {
                // The worker never panics; a join error only means it already unwound.
                let _ = handle.join();
                return true;
            }
            if Instant::now() >= deadline {
                return false;
            }
            thread::sleep(self.config.poll_step());
        }
    }
}

impl Drop for HeartbeatSession {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Interval used by the scripted-link tests. Small so the suite is fast; every wait below is
    // derived from it.
    const TEST_INTERVAL_S: f64 = 0.06;
    const TEST_MAX_MISSED: i64 = 3;

    #[derive(Clone, Copy, PartialEq, Eq)]
    enum Behavior {
        AckEveryHeartbeat,
        Silent,
        PollError,
        ServerDeregisters,
        AnswersDeregistration,
        IgnoresDeregistration,
    }

    #[derive(Default)]
    struct FakeState {
        sent: u32,
        acked: u32,
        pending_ack: bool,
        overlapping_sends: u32,
        dereg_sent: bool,
        disconnected: bool,
    }

    struct FakeLink {
        state: Arc<Mutex<FakeState>>,
        behavior: Behavior,
    }

    impl FakeLink {
        fn lock(&self) -> std::sync::MutexGuard<'_, FakeState> {
            self.state.lock().expect("fake state lock")
        }
    }

    impl SessionLink for FakeLink {
        fn poll(&mut self) -> Result<LinkEvent, String> {
            let behavior = self.behavior;
            let mut state = self.lock();
            match behavior {
                Behavior::AckEveryHeartbeat => {
                    if state.pending_ack {
                        state.pending_ack = false;
                        state.acked += 1;
                        Ok(LinkEvent::HeartbeatAck)
                    } else {
                        Ok(LinkEvent::Idle)
                    }
                }
                Behavior::PollError => Err("scripted failure".to_string()),
                Behavior::ServerDeregisters => Ok(LinkEvent::Deregistered),
                Behavior::AnswersDeregistration => {
                    if state.dereg_sent {
                        Ok(LinkEvent::Deregistered)
                    } else {
                        Ok(LinkEvent::Idle)
                    }
                }
                Behavior::Silent | Behavior::IgnoresDeregistration => Ok(LinkEvent::Idle),
            }
        }

        fn send_heartbeat(&mut self) -> Result<(), String> {
            let mut state = self.lock();
            if state.pending_ack {
                state.overlapping_sends += 1;
            }
            state.sent += 1;
            state.pending_ack = true;
            Ok(())
        }

        fn send_deregistration(&mut self) -> Result<(), String> {
            self.lock().dereg_sent = true;
            Ok(())
        }

        fn is_registered(&self) -> bool {
            true
        }

        fn disconnect(&mut self) {
            self.lock().disconnected = true;
        }
    }

    fn start(behavior: Behavior) -> (HeartbeatSession, Arc<Mutex<FakeState>>) {
        let config =
            HeartbeatConfig::new(TEST_INTERVAL_S, TEST_MAX_MISSED).expect("valid test config");
        let state = Arc::new(Mutex::new(FakeState::default()));
        let shared = Arc::new(HeartbeatShared::new());
        shared.mark_alive();
        let worker_state = Arc::clone(&state);
        let worker_shared = Arc::clone(&shared);
        let worker = thread::spawn(move || {
            let mut link = FakeLink {
                state: worker_state,
                behavior,
            };
            run_heartbeat_loop(&mut link, &config, &worker_shared);
        });
        (
            HeartbeatSession::new(shared, worker, config, "agent".to_string()),
            state,
        )
    }

    /// Wait up to `intervals` heartbeat intervals for `condition`.
    fn wait_until(intervals: u32, condition: impl Fn() -> bool) -> bool {
        let deadline = Instant::now() + Duration::from_secs_f64(TEST_INTERVAL_S) * intervals;
        while Instant::now() < deadline {
            if condition() {
                return true;
            }
            thread::sleep(Duration::from_secs_f64(TEST_INTERVAL_S) / POLL_STEPS_PER_INTERVAL);
        }
        condition()
    }

    #[test]
    fn config_rejects_non_positive_and_non_finite_interval() {
        for bad in [0.0, -1.0, f64::NAN, f64::INFINITY, f64::NEG_INFINITY, 1e300] {
            assert!(HeartbeatConfig::new(bad, 3).is_err(), "interval {bad}");
        }
    }

    #[test]
    fn config_rejects_interval_too_small_for_a_worker_step() {
        assert!(HeartbeatConfig::new(1e-12, 3).is_err());
    }

    #[test]
    fn config_rejects_non_positive_max_missed() {
        for bad in [0, -1, i64::MIN] {
            assert!(HeartbeatConfig::new(1.0, bad).is_err(), "max_missed {bad}");
        }
    }

    #[test]
    fn config_derives_step_from_interval() {
        let config = HeartbeatConfig::new(5.0, 3).expect("valid config");
        assert_eq!(config.interval(), Duration::from_secs(5));
        assert_eq!(config.max_missed_acks(), 3);
        assert_eq!(
            config.poll_step(),
            Duration::from_secs(5) / POLL_STEPS_PER_INTERVAL
        );
    }

    #[test]
    fn stop_exits_worker_and_is_safe_twice() {
        let (mut session, state) = start(Behavior::AckEveryHeartbeat);
        assert!(session.is_alive());
        assert!(session.stop(), "worker must exit within the bound");
        assert!(!session.is_alive());
        assert!(state.lock().expect("lock").disconnected);
        assert!(session.stop(), "second stop is a no-op");
        assert_eq!(session.error(), "", "a clean stop records no error");
    }

    #[test]
    fn drop_while_running_stops_the_worker() {
        let (session, state) = start(Behavior::AckEveryHeartbeat);
        assert!(session.is_alive());
        drop(session);
        assert!(
            state.lock().expect("lock").disconnected,
            "drop must have joined the worker after it disconnected"
        );
    }

    #[test]
    fn acked_heartbeats_keep_the_session_alive_with_one_in_flight() {
        let (mut session, state) = start(Behavior::AckEveryHeartbeat);
        assert!(wait_until(30, || state.lock().expect("lock").acked >= 3));
        assert!(session.is_alive());
        {
            let guard = state.lock().expect("lock");
            assert_eq!(guard.overlapping_sends, 0, "never two heartbeats in flight");
            assert!(guard.sent >= guard.acked);
        }
        session.stop();
    }

    #[test]
    fn missing_acks_mark_the_session_dead_after_max_missed_intervals() {
        let (mut session, state) = start(Behavior::Silent);
        assert!(wait_until(30, || !session.is_alive()));
        assert!(session.error().contains("no heartbeat ack"));
        assert_eq!(
            state.lock().expect("lock").sent,
            1,
            "no second heartbeat while the first is unacked"
        );
        assert!(session.stop());
    }

    #[test]
    fn link_error_marks_the_session_dead_with_the_reason() {
        let (mut session, _state) = start(Behavior::PollError);
        assert!(wait_until(30, || !session.is_alive()));
        assert!(session.error().contains("scripted failure"));
        assert!(session.stop());
    }

    #[test]
    fn server_deregistration_marks_the_session_dead() {
        let (mut session, _state) = start(Behavior::ServerDeregisters);
        assert!(wait_until(30, || !session.is_alive()));
        assert!(session.error().contains("deregistered"));
        assert!(session.stop());
    }

    #[test]
    fn deregister_over_live_link_reports_confirmation() {
        let (mut session, state) = start(Behavior::AnswersDeregistration);
        assert!(session.deregister());
        assert!(state.lock().expect("lock").dereg_sent);
        assert!(!session.is_alive());
    }

    #[test]
    fn deregister_without_answer_reports_failure_within_bound() {
        let (mut session, _state) = start(Behavior::IgnoresDeregistration);
        assert!(!session.deregister());
        assert!(!session.is_alive());
    }

    #[test]
    fn deregister_after_death_reports_failure() {
        let (mut session, _state) = start(Behavior::PollError);
        assert!(wait_until(30, || !session.is_alive()));
        assert!(!session.deregister());
    }
}
