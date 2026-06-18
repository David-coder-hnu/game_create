# GUT 测试: RecipeDB
extends GutTest

func before_all():
	# RecipeDB 是 Autoload, 在测试中直接访问
	pass

func test_black_powder_is_discovered():
	assert_true(RecipeDB.is_discovered("black_powder"), "黑火药应该在开局已知")

func test_match_black_powder():
	var result = RecipeDB.match({"sulfur": 15.0, "saltpeter": 75.0, "charcoal": 10.0}, 1, 0)
	assert_eq(result.get("id", ""), "black_powder", "精确配方应该匹配黑火药")

func test_match_with_tolerance():
	# 73% 应该在 75% 的 5% 量化桶内 → 75%
	var result = RecipeDB.match({"sulfur": 14.0, "saltpeter": 73.0, "charcoal": 13.0}, 1, 0)
	assert_eq(result.get("id", ""), "black_powder", "±5% 容差应该匹配")

func test_no_match_garbage():
	var result = RecipeDB.match({"sulfur": 99.0, "saltpeter": 0.0, "charcoal": 1.0}, 5, 100)
	assert_true(result.is_empty(), "无效组合应该返回空")

func test_tnt_locked():
	var owned = EquipmentStore.get_owned_operations()
	assert_false("nitration" in owned, "初始设备不应有硝化反应")
	assert_false("heat_controlled" in owned, "初始设备不应有精确控温")

func test_discover_emits_signal():
	watch_signals(RecipeDB)
	RecipeDB.discover("brown_powder")
	assert_signal_emitted(RecipeDB, "recipe_discovered")
