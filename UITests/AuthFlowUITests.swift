import XCTest

final class AuthFlowUITests: XCTestCase {
    func testAuthenticationScreenDisplaysLoginControls() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["vibecodeGram"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Имя пользователя"].exists)
        XCTAssertTrue(app.secureTextFields["Пароль"].exists)
        XCTAssertTrue(app.buttons["Войти"].exists)
        XCTAssertTrue(app.buttons["Создать аккаунт"].exists)
    }
}
