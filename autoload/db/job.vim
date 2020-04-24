" Hide pointless `No matching autocommands` in Vim
if !has('nvim')
  augroup db_dummy_autocmd
    autocmd!
    autocmd User DBQueryStart "
    autocmd User DBQueryFinished "
  augroup END
endif

let s:vim_job = {'output': '' }
function! s:vim_job.cb(job, data) dict abort
  if type(a:data) ==? type(0)
    let self.output = split(self.output, "\n", 1)
    return s:on_job_done(self)
  endif
  let self.output .= a:data
endfunction

function! s:nvim_job_cb(jobid, data, event) dict abort
  if a:event ==? 'exit'
    return s:on_job_done(self)
  endif
  call extend(self.output, a:data)
endfunction

function! s:on_job_done(job) abort
  call setbufvar(a:job.bufnr, 'db_job_id', '')
  doautocmd User DBQueryFinished
  return a:job.callback(a:job.output)
endfunction

function! db#job#run(cmd, callback) abort
  doautocmd User DBQueryStart
  if get(g:, 'db_async', 0) && has('nvim')
    call s:check_job_running()
    let b:db_job_id = jobstart(a:cmd, {
          \ 'on_stdout': function('s:nvim_job_cb'),
          \ 'on_stderr': function('s:nvim_job_cb'),
          \ 'on_exit': function('s:nvim_job_cb'),
          \ 'output': [],
          \ 'bufnr': bufnr('%'),
          \ 'callback': a:callback,
          \ 'stdout_buffered': 1,
          \ 'stderr_buffered': 1,
          \ })
    return b:db_job_id
  endif

  if get(g:, 'db_async', 0) && exists('*job_start')
    call s:check_job_running()
    let fn = copy(s:vim_job)
    let fn.callback = a:callback
    let fn.bufnr = bufnr('%')
    let b:db_job_id = job_start([&shell, '-c', a:cmd], {
          \ 'out_cb': fn.cb,
          \ 'err_cb': fn.cb,
          \ 'exit_cb': fn.cb,
          \ 'mode': 'raw'
          \ })
    return b:db_job_id
  endif

  if exists('*systemlist')
    let lines = systemlist(a:cmd)
  else
    let lines = split(system(a:cmd), "\n", 1)
  endif
  doautocmd User DBQueryFinished
  return a:callback(lines)
endfunction

function! s:check_job_running() abort
  if !exists('b:db_job_id') || b:db_job_id ==? ''
    return
  endif
  throw 'DB: Query already running'
endfunction
