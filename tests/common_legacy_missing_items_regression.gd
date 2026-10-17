extends SceneTree

# Legacy save compatibility regression. Does not read or write user:// saves.
var checked: int = 0
var errors: Array[String] = []

func verify(label: String, condition: bool) -> void:
    checked += 1
    if not condition:
        errors.append(label)
        printerr("FAIL " + label)

func _initialize() -> void:
    var empty_run: Dictionary = {"inventory": {}, "run": {}}
    Region1RunController.normalize_legacy_common_sockets(empty_run)
    verify("legacy hub without run.items", empty_run["run"].is_empty())
    var shop_without_stock: Dictionary = {"inventory": {}, "run": {"kind": "shop"}}
    Region1RunController.normalize_legacy_common_sockets(shop_without_stock)
    verify("legacy shop without run.items/stock", not shop_without_stock["run"].has("items"))
    # Missing optional arrays used to crash at saved_run[field].
    var missing_all: Dictionary = {"run": {}}
    Region1RunController.normalize_legacy_common_sockets(missing_all)
    verify("missing bag stock rewards tolerated", missing_all["run"].is_empty())
    var bag_only: Dictionary = {"run": {"bag": [{"rarity": "Common", "socket_count": 1, "socket_cap": 1}]}}
    Region1RunController.normalize_legacy_common_sockets(bag_only)
    verify("only bag present normalizes Common", bag_only["run"]["bag"][0]["socket_count"] == 0 and bag_only["run"]["bag"][0]["socket_cap"] == 0)
    var stock_only: Dictionary = {"run": {"stock": [{"rarity": "Common", "socket_count": 1, "socket_cap": 1}]}}
    Region1RunController.normalize_legacy_common_sockets(stock_only)
    verify("only stock present normalizes Common", stock_only["run"]["stock"][0]["socket_count"] == 0 and stock_only["run"]["stock"][0]["socket_cap"] == 0)
    var rewards_only: Dictionary = {"run": {"rewards": [{"rarity": "Common", "socket_count": 1, "socket_cap": 1}]}}
    Region1RunController.normalize_legacy_common_sockets(rewards_only)
    verify("only rewards present normalizes Common", rewards_only["run"]["rewards"][0]["socket_count"] == 0 and rewards_only["run"]["rewards"][0]["socket_cap"] == 0)
    var nonarray: Dictionary = {"run": {"bag": null, "stock": {}, "rewards": "legacy"}}
    Region1RunController.normalize_legacy_common_sockets(nonarray)
    verify("unexpected optional field types tolerated", nonarray["run"]["bag"] == null and nonarray["run"]["stock"] is Dictionary and nonarray["run"]["rewards"] == "legacy")
    var missing_bag: Dictionary = {"run": {"stock": [], "rewards": []}}
    Region1RunController.normalize_legacy_common_sockets(missing_bag)
    verify("missing bag with other arrays tolerated", not missing_bag["run"].has("bag"))
    var missing_stock: Dictionary = {"run": {"bag": [], "rewards": []}}
    Region1RunController.normalize_legacy_common_sockets(missing_stock)
    verify("missing stock with other arrays tolerated", not missing_stock["run"].has("stock"))
    var missing_rewards: Dictionary = {"run": {"bag": [], "stock": []}}
    Region1RunController.normalize_legacy_common_sockets(missing_rewards)
    verify("missing rewards with other arrays tolerated", not missing_rewards["run"].has("rewards"))
    var bag_common: Dictionary = {"rarity": "Common", "socket_count": 1, "socket_cap": 1}
    var stock_common: Dictionary = {"rarity": "Common", "socket_count": 1, "socket_cap": 1}
    var reward_common: Dictionary = {"rarity": "Common", "socket_count": 1, "socket_cap": 1}
    var run_common: Dictionary = {"rarity": "Common", "socket_count": 1, "socket_cap": 1}
    var owned_common: Dictionary = {"rarity": "Common", "socket_count": 1, "socket_cap": 1}
    var rare: Dictionary = {"rarity": "Rare", "socket_count": 2, "socket_cap": 2}
    var legacy: Dictionary = {
        "inventory": {"A": owned_common, "B": rare},
        "hub_stock": [{"rarity": "Common", "socket_count": 1, "socket_cap": 1}],
        "run": {"items": {"main_weapon": run_common}, "bag": [bag_common], "stock": [stock_common], "rewards": [reward_common]}
    }
    Region1RunController.normalize_legacy_common_sockets(legacy)
    for item in [bag_common, stock_common, reward_common, run_common, owned_common, legacy["hub_stock"][0]]:
        verify("legacy Common sockets become zero", int(item.get("socket_count", -1)) == 0 and int(item.get("socket_cap", -1)) == 0)
    verify("non-Common sockets unchanged", int(rare["socket_count"]) == 2 and int(rare["socket_cap"]) == 2)
    var missing_items: Dictionary = {"run": {"items": null, "bag": [], "stock": [], "rewards": []}}
    Region1RunController.normalize_legacy_common_sockets(missing_items)
    verify("legacy null items tolerated", missing_items["run"]["items"] == null)
    print("COMMON_LEGACY_MISSING_ITEMS checks=%d failures=%d" % [checked, errors.size()])
    quit(0 if errors.is_empty() else 1)
