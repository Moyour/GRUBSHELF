import Foundation

/// Maps Apple Vision image-classification identifiers to GrubShelf pantry categories and display names.
enum ProductRecognitionGroceryMapper {
    static func displayName(fromVisionIdentifier raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map { String($0).capitalized }
            .joined(separator: " ")
        return cleaned.isEmpty ? String(localized: "Grocery item") : cleaned
    }

    /// Returns a category from `AddEditPantryItemViewModel.predefinedCategories`, or `"Other"`.
    static func pantryCategory(forVisionIdentifier raw: String) -> String {
        let id = normalize(raw)
        if let c = exact[id] { return c }
        for sep in ["_", "/", "-"] {
            for part in id.split(separator: Character(sep)) {
                let p = String(part)
                if let c = exact[p] { return c }
            }
        }
        return heuristicCategory(id) ?? "Other"
    }

    private static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func heuristicCategory(_ id: String) -> String? {
        let seafood = ["fish", "salmon", "tuna", "cod", "trout", "mackerel", "sardine", "anchovy", "shrimp", "prawn", "crab", "lobster", "oyster", "clam", "mussel", "scallop", "squid", "octopus", "sushi", "sashimi", "ceviche", "seafood", "caviar"]
        if seafood.contains(where: { id.contains($0) }) { return "Seafood" }

        let meat = ["chicken", "beef", "pork", "lamb", "veal", "turkey", "duck", "goose", "steak", "bacon", "ham", "sausage", "hot_dog", "hamburger", "burger", "meatball", "ribs", "drumstick", "wing", "pepperoni", "salami", "prosciutto", "jerky", "poultry", "meat"]
        if meat.contains(where: { id.contains($0) }) { return "Meat" }

        let dairy = ["milk", "cheese", "yogurt", "yoghurt", "cream", "butter", "dairy", "mozzarella", "cheddar", "feta", "ricotta", "parmesan", "egg"]
        if dairy.contains(where: { id.contains($0) }) { return "Dairy" }

        if id.contains("pineapple") || id.contains("grapefruit") { return "Fruits" }
        let fruit = ["fruit", "banana", "orange", "melon", "citrus", "mango", "peach", "pear", "plum", "cherry", "kiwi", "avocado", "coconut", "fig", "pomegranate", "berry", "grape", "apple"]
        if fruit.contains(where: { id.contains($0) }) { return "Fruits" }

        let bev = ["juice", "soda", "cola", "coffee", "espresso", "latte", "tea", "beer", "wine", "cocktail", "drink", "beverage", "smoothie", "lemonade", "water", "cocoa"]
        if bev.contains(where: { id.contains($0) }) { return "Beverages" }

        let frozen = ["ice_cream", "popsicle", "gelato", "sorbet", "frozen"]
        if frozen.contains(where: { id.contains($0) }) { return "Frozen" }

        let snacks = ["cookie", "biscuit", "candy", "chocolate", "snack", "chip", "crisp", "popcorn", "donut", "doughnut", "brownie", "cake", "pastry", "pie", "tart", "gummy", "lollipop", "nuts", "trail_mix"]
        if snacks.contains(where: { id.contains($0) }) { return "Snacks" }

        let grains = ["bread", "bagel", "toast", "bun", "roll", "croissant", "muffin", "waffle", "pancake", "cereal", "oat", "granola", "rice", "pasta", "noodle", "spaghetti", "macaroni", "quinoa", "barley", "flour", "tortilla", "cracker", "pretzel", "grain"]
        if grains.contains(where: { id.contains($0) }) { return "Grains" }

        let cond = ["sauce", "ketchup", "mustard", "mayonnaise", "mayo", "dressing", "vinegar", "oil", "spice", "herb", "seasoning", "syrup", "honey", "jam", "jelly", "pickle", "relish", "condiment", "pesto", "salsa", "soy_sauce", "hot_sauce"]
        if cond.contains(where: { id.contains($0) }) { return "Condiments" }

        let veg = ["vegetable", "veggie", "salad", "greens", "tomato", "jalapeno", "chili", "onion", "garlic", "potato", "carrot", "broccoli", "cabbage", "lettuce", "spinach", "kale", "cucumber", "zucchini", "eggplant", "cauliflower", "mushroom", "bean_sprout", "sprout", "ginger", "beet", "radish", "turnip", "parsnip", "leek", "asparagus", "celery", "squash", "pumpkin", "scallion", "arugula", "okra"]
        if veg.contains(where: { id.contains($0) }) { return "Vegetables" }

        let staples = ["yam", "plantain", "cassava", "fufu", "semolina", "gari", "injera", "couscous", "millet", "sorghum"]
        if staples.contains(where: { id.contains($0) }) { return "African Staples" }

        let spices = ["curry", "suya", "berbere", "harissa", "jollof", "pepper soup"]
        if spices.contains(where: { id.contains($0) }) { return "African Spices" }

        if id.contains("food") || id.contains("meal") || id.contains("dish") { return "Other" }

        return nil
    }

    /// Returns `true` when the raw Vision identifier maps to any known food category
    /// (exact dictionary hit **or** heuristic keyword match).
    static func isKnownFoodIdentifier(_ raw: String) -> Bool {
        let id = normalize(raw)
        if exact[id] != nil { return true }
        for sep in ["_", "/", "-"] {
            for part in id.split(separator: Character(sep)) {
                if exact[String(part)] != nil { return true }
            }
        }
        return heuristicCategory(id) != nil
    }

    /// Exact and synonym mappings for common Vision / ImageNet-style food identifiers.
    private static let exact: [String: String] = {
        var m: [String: String] = [:]

        func add(_ pairs: [(String, String)]) {
            for (k, v) in pairs { m[k] = v }
        }

        add([
            ("apple", "Fruits"), ("banana", "Fruits"), ("orange", "Fruits"), ("lemon", "Fruits"), ("lime", "Fruits"),
            ("grape", "Fruits"), ("strawberry", "Fruits"), ("blueberry", "Fruits"), ("blackberry", "Fruits"),
            ("raspberry", "Fruits"), ("watermelon", "Fruits"), ("melon", "Fruits"), ("cantaloupe", "Fruits"),
            ("honeydew", "Fruits"), ("mango", "Fruits"), ("pineapple", "Fruits"), ("peach", "Fruits"),
            ("pear", "Fruits"), ("plum", "Fruits"), ("cherry", "Fruits"), ("apricot", "Fruits"), ("nectarine", "Fruits"),
            ("kiwi", "Fruits"), ("fig", "Fruits"), ("date", "Fruits"), ("pomegranate", "Fruits"), ("coconut", "Fruits"),
            ("avocado", "Fruits"), ("papaya", "Fruits"), ("guava", "Fruits"), ("passion fruit", "Fruits"),
            ("passion_fruit", "Fruits"), ("dragon_fruit", "Fruits"), ("lychee", "Fruits"), ("berry", "Fruits"),
            ("fruit", "Fruits"), ("citrus_fruit", "Fruits"), ("jackfruit", "Fruits"),

            ("tomato", "Vegetables"), ("cherry_tomato", "Vegetables"), ("bell_pepper", "Vegetables"),
            ("cucumber", "Vegetables"), ("carrot", "Vegetables"), ("broccoli", "Vegetables"), ("cauliflower", "Vegetables"),
            ("lettuce", "Vegetables"), ("cabbage", "Vegetables"), ("kale", "Vegetables"), ("spinach", "Vegetables"),
            ("arugula", "Vegetables"), ("onion", "Vegetables"), ("garlic", "Vegetables"), ("potato", "Vegetables"),
            ("sweet_potato", "Vegetables"), ("yam", "African Staples"), ("eggplant", "Vegetables"), ("zucchini", "Vegetables"),
            ("squash", "Vegetables"), ("pumpkin", "Vegetables"), ("corn", "Vegetables"), ("peas", "Vegetables"),
            ("green_beans", "Vegetables"), ("asparagus", "Vegetables"), ("celery", "Vegetables"), ("beet", "Vegetables"),
            ("radish", "Vegetables"), ("turnip", "Vegetables"), ("mushroom", "Vegetables"), ("ginger", "Vegetables"),
            ("vegetable", "Vegetables"), ("salad", "Vegetables"), ("brussels_sprouts", "Vegetables"), ("leek", "Vegetables"),
            ("scallion", "Vegetables"), ("chives", "Vegetables"), ("parsnip", "Vegetables"), ("okra", "Vegetables"),

            ("milk", "Dairy"), ("cheese", "Dairy"), ("yogurt", "Dairy"), ("butter", "Dairy"), ("cream", "Dairy"),
            ("dairy", "Dairy"), ("egg", "Dairy"), ("eggs", "Dairy"), ("cottage_cheese", "Dairy"), ("sour_cream", "Dairy"),

            ("chicken", "Meat"), ("beef", "Meat"), ("pork", "Meat"), ("lamb", "Meat"), ("veal", "Meat"),
            ("steak", "Meat"), ("bacon", "Meat"), ("sausage", "Meat"), ("meat", "Meat"), ("ribs", "Meat"),
            ("turkey", "Meat"), ("duck", "Meat"), ("ham", "Meat"), ("meatball", "Meat"), ("hot_dog", "Meat"),
            ("hamburger", "Meat"), ("pepperoni", "Meat"), ("salami", "Meat"), ("prosciutto", "Meat"),

            ("fish", "Seafood"), ("salmon", "Seafood"), ("tuna", "Seafood"), ("cod", "Seafood"), ("trout", "Seafood"),
            ("shrimp", "Seafood"), ("crab", "Seafood"), ("lobster", "Seafood"), ("oyster", "Seafood"), ("clam", "Seafood"),
            ("mussel", "Seafood"), ("scallop", "Seafood"), ("squid", "Seafood"), ("octopus", "Seafood"),
            ("sushi", "Seafood"), ("sashimi", "Seafood"), ("seafood", "Seafood"), ("fillet", "Seafood"),

            ("bread", "Grains"), ("bagel", "Grains"), ("croissant", "Grains"), ("biscuit", "Grains"), ("bun", "Grains"),
            ("roll", "Grains"), ("pita", "Grains"), ("naan", "Grains"), ("tortilla", "Grains"), ("rice", "Grains"),
            ("pasta", "Grains"), ("noodle", "Grains"), ("spaghetti", "Grains"), ("macaroni", "Grains"), ("cereal", "Grains"),
            ("oatmeal", "Grains"), ("granola", "Grains"), ("quinoa", "Grains"), ("couscous", "Grains"), ("barley", "Grains"),
            ("flour", "Grains"), ("cracker", "Grains"), ("pretzel", "Grains"), ("waffle", "Grains"), ("pancake", "Grains"),

            ("cookie", "Snacks"), ("chips", "Snacks"), ("candy", "Snacks"), ("chocolate", "Snacks"), ("snack", "Snacks"),
            ("brownie", "Snacks"), ("donut", "Snacks"), ("doughnut", "Snacks"), ("popcorn", "Snacks"), ("nuts", "Snacks"),
            ("trail_mix", "Snacks"), ("granola_bar", "Snacks"), ("cake", "Snacks"), ("pastry", "Snacks"), ("pie", "Snacks"),

            ("juice", "Beverages"), ("soda", "Beverages"), ("beer", "Beverages"), ("wine", "Beverages"),
            ("coffee", "Beverages"), ("espresso", "Beverages"), ("tea", "Beverages"), ("beverage", "Beverages"),
            ("smoothie", "Beverages"), ("cocktail", "Beverages"), ("water", "Beverages"), ("lemonade", "Beverages"),

            ("ice_cream", "Frozen"), ("frozen", "Frozen"), ("popsicle", "Frozen"), ("gelato", "Frozen"),

            ("sauce", "Condiments"), ("ketchup", "Condiments"), ("mayonnaise", "Condiments"), ("mustard", "Condiments"),
            ("vinegar", "Condiments"), ("dressing", "Condiments"), ("pickle", "Condiments"), ("relish", "Condiments"),
            ("condiment", "Condiments"), ("honey", "Condiments"), ("jam", "Condiments"), ("syrup", "Condiments"),
            ("pesto", "Condiments"), ("salsa", "Condiments"), ("soy_sauce", "Condiments"),

            ("pizza", "Snacks"), ("burrito", "Grains"), ("taco", "Grains"), ("sandwich", "Grains"), ("wrap", "Grains"),
            ("french_fries", "Snacks"), ("fries", "Snacks"), ("stew", "Meat"), ("curry", "African Spices"),
            ("noodles", "Grains"), ("ramen", "Grains"), ("lasagna", "Grains"), ("ravioli", "Grains"),

            ("canned_food", "Other"), ("soup", "Other"), ("packaged_food", "Other"), ("food", "Other"),
            ("meal", "Other"), ("bento", "Other"), ("fast_food", "Other"), ("breakfast", "Other"), ("lunch", "Other"),
            ("dinner", "Other"), ("dessert", "Snacks"), ("bakery", "Grains"), ("baked_goods", "Snacks"),
        ])

        return m
    }()
}
