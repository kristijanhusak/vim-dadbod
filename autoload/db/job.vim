let s:vim_job = {'output': '' }
function! s:vim_job.cb(job, data) dict abort
  if type(a:data) ==? type(0)
    if !empty(self.output)
      let self.output = split(self.output, "\n", 1)
    else
      let self.output = []
    endif
    return s:on_job_done(self, a:data)
  endif
  let self.output .= a:data
endfunction

function! s:nvim_job_cb(jobid, data, event) dict abort
  if a:event ==? 'exit'
    return s:on_job_done(self, a:data)
  endif
  call extend(self.output, a:data)
endfunction

function! s:on_job_done(job, data) abort
  call settabvar(a:job.tabnr, 'db_job_id', '')
  if a:data !=? 0 && empty(a:job.output)
    return a:job.callback(['Exit with status '.a:data])
  endif
  return a:job.callback(a:job.output)
endfunction

function! db#job#run(cmd, callback) abort
  if get(g:, 'db_async', 0) && has('nvim')
    let t:db_job_id = jobstart(a:cmd, {
          \ 'on_stdout': function('s:nvim_job_cb'),
          \ 'on_stderr': function('s:nvim_job_cb'),
          \ 'on_exit': function('s:nvim_job_cb'),
          \ 'output': [],
          \ 'tabnr': tabpagenr(),
          \ 'callback': a:callback,
          \ 'stdout_buffered': 1,
          \ 'stderr_buffered': 1,
          \ })
    return t:db_job_id
  endif

  if get(g:, 'db_async', 0) && exists('*job_start')
    let fn = copy(s:vim_job)
    let fn.callback = a:callback
    let fn.tabnr = tabpagenr()
    let t:db_job_id = job_start([&shell, '-c', a:cmd], {
          \ 'out_cb': fn.cb,
          \ 'err_cb': fn.cb,
          \ 'exit_cb': fn.cb,
          \ 'mode': 'raw'
          \ })
    return t:db_job_id
  endif

  if exists('*systemlist')
    let lines = systemlist(a:cmd)
  else
    let lines = split(system(a:cmd), "\n", 1)
  endif
  return a:callback(lines)
endfunction

function! db#job#check_job_running() abort
  if !exists('t:db_job_id') || t:db_job_id ==? ''
    return
  endif
  throw 'DB: Query already running'
endfunction

function! db#job#cancel() abort
  if !exists('t:db_job_id') || t:db_job_id ==? ''
    return
  endif

  if has('nvim')
    return jobstop(t:db_job_id)
  endif

  if exists('*job_stop')
    return job_stop(t:db_job_id)
  endif
endfunction
