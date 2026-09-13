import Testing
@testable import app_four

@Suite struct GemmaChatTemplateTests {
    @Test func singleTurnFoldsSystemIntoUserTurn() {
        let out = GemmaChatTemplate.singleTurn(system: "SYS", user: "USR")
        #expect(out == "<start_of_turn>user\nSYS\n\nUSR<end_of_turn>\n<start_of_turn>model\n")
    }

    @Test func singleTurnWithEmptySystemHasNoLeadingBlock() {
        let out = GemmaChatTemplate.singleTurn(system: "", user: "USR")
        #expect(out == "<start_of_turn>user\nUSR<end_of_turn>\n<start_of_turn>model\n")
    }

    @Test func singleTurnTrimsSystemWhitespace() {
        let out = GemmaChatTemplate.singleTurn(system: "  \n SYS \n ", user: "USR")
        #expect(out == "<start_of_turn>user\nSYS\n\nUSR<end_of_turn>\n<start_of_turn>model\n")
    }

    @Test func renderInterleavesRolesAndAppendsModelOpener() {
        let out = GemmaChatTemplate.render([
            .init(role: .user, text: "a"),
            .init(role: .model, text: "b"),
            .init(role: .user, text: "c"),
        ])
        #expect(out == "<start_of_turn>user\na<end_of_turn>\n<start_of_turn>model\nb<end_of_turn>\n<start_of_turn>user\nc<end_of_turn>\n<start_of_turn>model\n")
    }

    @Test func delimiterConstants() {
        #expect(GemmaChatTemplate.startOfTurn == "<start_of_turn>")
        #expect(GemmaChatTemplate.endOfTurn == "<end_of_turn>")
    }
}
