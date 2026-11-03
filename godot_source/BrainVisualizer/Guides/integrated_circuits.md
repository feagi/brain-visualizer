# Integrated Circuits

An integrated circuit is a circuit you configure in Brain Visualizer. On **Add Circuit**, it is the tile with a gold **IC** chip on the top-right corner of its image. Hover the chip for the short explanation. Click the image or the chip to open its configuration window.

The other tiles on that window, such as Logic AND and Logic OR, are genomes or connectomes. Choosing one of those uploads the packaged circuit. The placement shadow is drawn on the brain monitor of the circuit you opened Add Circuit from. The top bar Circuits + uses the root scene. Choosing an integrated circuit does not upload a genome. You set it up for the brain circuit you already have open.

A [brain circuit](brain_circuits.md) is the container: a named place that holds cortical areas and smaller circuits. An integrated circuit is something you build inside that container. The integrated circuit available now is the **Classifier**.

## What a Classifier Does

A classifier learns a correspondence between a sample pattern and a class pattern. It is two memory areas joined by an associative mapping, plus the areas Brain Visualizer creates around them.

It is made of cortical areas in the brain circuit where you create it:

- **Sample memory** and **class memory** are created with the classifier. Their names are the classifier name plus `_sample_mem` and `_class_mem`. Sample memory holds the patterns. Class memory holds the labels. An associative mapping binds the two.
- **Sample inputs** and **class inputs** are cortical areas you already have. You connect them after the classifier exists. A sample input uses the **Classifier Sample** rule and lands on sample memory. A class input uses the **Classifier Class** rule and lands on class memory. Several inputs of one kind are hashed together as one pattern. Memory areas and interconnect areas are both valid inputs. Deleting the classifier does not delete those inputs.
- Each class input gets its own **class output**. FEAGI creates it when you connect that class input, and its shape matches the class input. Disconnecting the class input deletes that output.
- The **error area** is a 1x1x1 area created with the classifier. It fires on the next burst when a class input and its class output disagree, or when one class output has more than one neuron firing. Several class outputs with one neuron each are not an error.
- **Correct answer from**, **Learn only while this fires**, and **Confidence output** are optional cortical areas you pick in the Reward Training section. They are not created with the classifier, and they are not peripheral inputs or outputs.

## How It Appears

Creating a classifier adds a circuit with the classifier's name. On the parent circuit, that region's plate shows the classifier as an input. The error area and each class output show as outputs.

The button that opens a circuit's interior is grayed out on this circuit. Its tooltip says "this is an integrated circuit and internals are not visible". Double-clicking the circuit does not open it either.

Sample memory is that input. It is the stamp you connect to with **Classifier Sample**. Class memory stays inside and is not shown as an input or an output.

**Memory Areas** lists sample memory and class memory under those names. **Interconnect Areas** lists each class output and the error area.

## Add a Classifier

1. Open the brain circuit that should contain it.
2. Hover **Circuits** and click **+**.
3. Choose **Classifier**.

The create window opens for that circuit. Connect sample and class inputs after the classifier exists.

### Create window

**Classifier name** is required. If that name is already used, the form reports "A classifier using this name already exists."

**3D Position** is the stamp's location. When a Brain Monitor for this circuit is open, a preview stamp appears there. Move the preview with the gizmo, or type the position. The two stay in step.

**Create Classifier** builds sample memory, class memory, the error area, and the associative mapping, then closes the window. A problem stays on the form in red, and the window stays open.

## Connect a Sample or a Class

Connect inputs after the classifier exists.

1. Right-click the source area and choose **Quick Connect**. The source must be a memory area, an interconnect area, an input area, or an output area.
2. Click the classifier: its node in Circuit Builder, or its stamp in Brain Monitor.
3. Choose **Classifier Sample** or **Classifier Class**.
4. Confirm.

Classifier Sample maps the source onto sample memory. Classifier Class maps it onto class memory and creates a class output with the same shape. In Brain Monitor the connection guide ends on the center of the stamp, unless another cortical volume lies in front of the stamp.

Quick Connect will not start from an area this classifier already owns. In that case the window tells you that a classifier input starts from a memory, interconnect, input, or output area.

## Edit a Classifier

Right-click the classifier and choose **Details**. The button tooltip is **Classifier properties**. This opens the classifier editor, not Cortical Area Details and not the circuit editor. Hover a label for a description of that setting. Those descriptions wrap to a narrow column.

If the editor is already open, selecting a different classifier loads that classifier. Selecting the same one again refreshes the neuron counts.

**Help**, at the bottom left, opens this section of the user guide. **Update** applies the main form and every section you changed below it, then closes the editor. If a section fails, the editor stays open and says which one. **Cancel** closes it without applying anything.

### Main form

- **Classifier ID** identifies the classifier. It cannot be edited.
- **Classifier Name** is the name shown on the node and used in the memory-area names.
- **Parent Circuit** is the brain circuit that contains the classifier. Change it here. The quick menu has no separate command for moving a classifier into another circuit.
- **3D Position** moves the stamp.
- **Sample Inputs**, **Class Outputs**, and **Error Area** are read-only. Inputs change through Quick Connect. A class output appears when its class input is connected, and disappears when that mapping is removed.

**Correct answer from**, **Learn only while this fires**, and **Confidence output** each have an edit icon beside the dropdown. The icon opens Cortical Area Explorer at the root circuit so you can pick an area from any other circuit.

### Neuron counts

**Sample Memory Neurons** and **Class Memory Neurons** are read-only. When FEAGI can report live counts, the field shows the total and the short-term / long-term split, as `(ST: … | LT: …)`. Hover the field for the three numbers written out.

### Sample memory, class memory, and the associative mapping

Three sections start collapsed. **Update** sends a section only when you changed a value in it.

**Sample Memory Area** and **Class Memory Area** edit the memory parameters of those two areas: Initial Neuron Lifespan, Lifespan Growth Rate, Longterm Memory Threshold, Temporal Depth, and MP Learning. Those parameters are the same ones documented for any memory area in [Cortical Area Details](cortical_area_details.md).

**Associative Memory Parameters** edits the mapping from sample memory to class memory.

These rows are always shown:

- **Plasticity Window** is how many bursts of co-activity count when reward learning is off. With reward learning on, FEAGI sets the eligibility window from the classifier's answer delay.
- **Plasticity Constant** is the base size of one weight step.
- **LTP Multiplier** scales a strengthening step. With reward training on, a Reward modulator commits it.
- **LTD Multiplier** scales a weakening step. With reward training on, a Punishment modulator commits it.
- **Synaptic Delay** is how many bursts a spike waits on this mapping before it reaches class memory. The minimum is 1.
Reward learning has its own **Reward Training** section. It does not need the associative mapping to be in cache.

- **Learn from right/wrong answers**: when on, the sample-to-class memory link learns with reward-modulated STDP from the modulators in **Reward** and **Punishment**. Those two rows appear only while it is on.

- **Reward** and **Punishment** pick the Reward modulators the classifier learns from, with the same chips as a connection's modulators. **Reward** offers modulators with positive strength; while one fires, the links that were active are strengthened. **Punishment** offers modulators with negative strength; while one fires, those links are weakened. The sample-to-class memory link uses reward-modulated learning (R-STDP). Every classifier has a **correct** area that fires when each class input is answered by its class output, and an **error** area that fires on a wrong or doubled answer. They drive the "*name* correct answer" modulator (offered under Reward) and the "*name* error" modulator (offered under Punishment); both are selected when reward learning is first turned on. Change a modulator's strength in the Modulators window.

If the memory area or the associative mapping is not available, the section says so and **Update** leaves it alone.

## Move, Reset, or Delete

Right-click the classifier.

- From Circuit Builder, **Relocate this classifier (2D)** follows the mouse. Left-click to commit the new position.
- From Brain Monitor, **Relocate this classifier (3D gizmo)** moves the stamp on the monitor that is already showing it.
- **Reset sample and class memory...** clears stored patterns in both memory areas. It uses the same cortical reset as a memory area. The open classifier editor reloads the short-term and long-term counts. The classifier, its connections, and the areas you connected as inputs stay in place.
- **Delete this classifier...** deletes the classifier, its sample memory, its class memory, its class outputs, its error and correct areas, and the "correct answer" and "error" modulators that fire from them. The sample inputs, class inputs, and any other modulators you selected are left in place.

The classifier quick menu does not include Open 3D Tab, clone, or Quick Connect. On the classifier circuit itself, Open Circuit in 3D Tab stays grayed out. Its tooltip says "this is an integrated circuit and internals are not visible".

## Related Topics

- [Brain Circuits](brain_circuits.md) - Containers that hold a classifier
- [Cortical Area Details](cortical_area_details.md) - Memory parameters used by sample and class memory
- [Circuit Builder](circuit_builder.md) - The 2D node
- [Brain Monitor](brain_monitor.md) - The stamp
- [Mapping Connections](mapping_connections.md) - Quick Connect
- [Quick Menu](quick_menu.md) - Details, relocate, reset, and delete

[Back to Overview](index.md)
