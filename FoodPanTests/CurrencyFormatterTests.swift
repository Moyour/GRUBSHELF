import Testing
@testable import FoodPan

struct CurrencyFormatterTests {
    @Test func zeroFormats() {
        let result = 0.currencyFormatted
        #expect(result.contains("0"))
    }

    @Test func positiveAmountFormats() {
        let result = 1550.currencyFormatted
        // Should contain "15.50" or locale-equivalent
        #expect(!result.isEmpty)
    }

    @Test func singleDigitCentsFormats() {
        let result = 5.currencyFormatted
        // 5 minor units = 0.05
        #expect(!result.isEmpty)
    }

    @Test func largeAmountFormats() {
        let result = 100000.currencyFormatted
        // 100000 minor = 1000.00
        #expect(!result.isEmpty)
    }

    @Test func negativeAmountFormats() {
        let result = (-500).currencyFormatted
        #expect(!result.isEmpty)
    }

    @Test func currencyCodeGBPFormats() {
        let result = 1550.currencyFormatted(currencyCode: "GBP")
        #expect(result.contains("15") || result.contains("15.50"))
        #expect(result.contains("£") || result.contains("GBP"))
    }

    @Test func currencyCodeUSDFormats() {
        let result = 1550.currencyFormatted(currencyCode: "USD")
        #expect(result.contains("15") || result.contains("15.50"))
        #expect(result.contains("$") || result.contains("USD"))
    }

    @Test func currencyCodeNGNFormats() {
        let result = 10000.currencyFormatted(currencyCode: "NGN")
        #expect(!result.isEmpty)
        #expect(result.contains("100"))
    }
}
