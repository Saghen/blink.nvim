// mod job;
// use crate::job::*;
//
// static ID_COUNTER: AtomicUsize = AtomicUsize::new(0);
// static JOBS: LazyLock<Mutex<HashMap<usize, Job>>> = LazyLock::new(|| Mutex::new(HashMap::new()));
//
// fn start_job(cmd: Vec<String>, options: JobStartOptions) -> usize {
//     let job = Job::new(cmd, options);
//     JOBS.lock().unwrap().insert(job.id, job);
//     job.id
// }
//
// fn job_pid(id: usize) -> Option<u32> {
//     let job = JOBS.lock().unwrap().get(&id);
//     let job = job.ok_or(mlua::Error::RuntimeError("Job not found".to_string()))?;
//     job.pid()
// }
//
// fn stop_job(id: usize) {
//     let job = JOBS.lock().unwrap().remove(&id);
//     if let Some(job) = job {
//         job.stop();
//     }
// }

// NOTE: skip_memory_check greatly improves performance
// https://github.com/mlua-rs/mlua/issues/318
// #[mlua::lua_module(skip_memory_check)]
// fn blink_job_internal(lua: &Lua) -> LuaResult<LuaTable> {
//     let exports = lua.create_table()?;
//     exports.set("start", lua.create_function(start_job)?)?;
//     Ok(exports)
// }
