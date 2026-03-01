// Services layer: business logic lives here. Keep functions small and testable.

pub mod example {
    pub async fn echo(input: &str) -> String {
        input.to_string()
    }
}
