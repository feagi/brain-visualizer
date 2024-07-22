extends RefCounted
class_name ConfigurablePopupButtonDefinition
## Instantiating [Button] for use in popups can easily lead to reference issues. Using this as a proxy

var text: String
var pressed_callables: Array[Callable] = []
