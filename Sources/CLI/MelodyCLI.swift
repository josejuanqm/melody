import ArgumentParser

/// Root CLI command that dispatches to subcommands like `create`, `build`, `dev`, and `validate`.
@main
struct MelodyCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "melody",
        abstract: "Melody — Declarative mobile app framework",
        version: "0.1.0",
        subcommands: [
            CreateCommand.self,
            ValidateCommand.self,
            BuildCommand.self,
            DevCommand.self,
            PluginsCommand.self,
        ]
    )
}
