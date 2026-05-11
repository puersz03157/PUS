extends Node2D
class_name DrawerNode2D
## 通用繪製節點：把 _draw 委派給可呼叫物件 fn(node)。

var fn: Callable


func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
