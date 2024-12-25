use mlua::prelude::*;
use std::collections::HashMap;

#[derive(Clone)]
pub struct JobStartOptions {
    pub cwd: String,
    pub env: HashMap<String, String>,
    pub clear_env: bool,

    pub stdin: bool,
    pub stdout_buffered: bool,
    pub stderr_buffered: bool,
    pub on_stderr: Option<LuaFunction>,
    pub on_stdout: Option<LuaFunction>,
    pub on_exit: Option<LuaFunction>,

    // Use msgpack-rpc to communicate with the job over stdio
    // on_stdout is ignored
    // on_stderr can still be used
    pub rpc: bool,

    // Detach the job process, it will not be killed when neovim exits
    pub detach: bool,

    // Connect the job to a new pseudo terminal, and its stream to the master file descriptor
    // on_stdout recieves all output
    // on_stderr is ignored
    pub pty: bool,
    // Width of the pty terminal
    pub width: Option<usize>,
    // Height of the pty terminal
    pub height: Option<usize>,
}

impl FromLua for JobStartOptions {
    fn from_lua(value: LuaValue, _lua: &'_ Lua) -> LuaResult<Self> {
        if let Some(tab) = value.as_table() {
            let cwd: String = tab.get("cwd").unwrap_or(
                std::env::current_dir()
                    .unwrap()
                    .to_str()
                    .unwrap()
                    .to_string(),
            );
            let env: HashMap<String, String> = tab.get("env").unwrap_or_default();
            let clear_env: bool = tab.get("clear_env").unwrap_or(false);

            let stdin: bool = tab.get("stdin").unwrap_or(true);
            let stdout_buffered: bool = tab.get("stdout_buffered").unwrap_or(false);
            let stderr_buffered: bool = tab.get("stderr_buffered").unwrap_or(false);
            let on_stderr: Option<LuaFunction> = tab.get("on_stderr")?;
            let on_stdout: Option<LuaFunction> = tab.get("on_stdout")?;
            let on_exit: Option<LuaFunction> = tab.get("on_exit")?;

            let rpc: bool = tab.get("rpc").unwrap_or(false);
            let detach: bool = tab.get("detach").unwrap_or(false);
            let pty: bool = tab.get("pty").unwrap_or(false);
            let width: Option<usize> = tab.get("width")?;
            let height: Option<usize> = tab.get("height")?;

            Ok(JobStartOptions {
                cwd,
                env,
                clear_env,

                stdin,
                stdout_buffered,
                stderr_buffered,
                on_stderr,
                on_stdout,
                on_exit,

                rpc,
                detach,
                pty,
                width,
                height,
            })
        } else {
            Err(mlua::Error::FromLuaConversionError {
                from: "LuaValue",
                to: "JobStartOptions".to_string(),
                message: None,
            })
        }
    }
}
