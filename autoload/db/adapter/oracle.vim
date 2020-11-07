if exists('g:autoloaded_db_adapter_oracle')
  finish
endif
let g:autoloaded_db_adapter_oracle = 1

function! db#adapter#oracle#canonicalize(url) abort
  return substitute(substitute(substitute(substitute(a:url,
        \ '^oracle:\zs\([^/@:]*\)/\([^/@:]*\)@/*\(.*\)$', '//\1:\2@\3', ''),
        \ '^oracle:\zs/\=/\@!', '///', ''),
        \ '^oracle:\zs//\ze\%(/\|$\)', '//localhost', ''),
        \ '^oracle:\zs//\ze[^@/]*\%(/\|$\)', '//system@', '')
endfunction

function! s:conn(url) abort
  return get(a:url, 'host', 'localhost')
        \ . (has_key(a:url, 'port') ? ':' . a:url.port : '')
        \ . (get(a:url, 'path', '/') == '/' ? '' : a:url.path)
endfunction

function! db#adapter#oracle#interactive(url) abort
  let url = db#url#parse(a:url)
  return get(g:, 'dbext_default_ORA_bin', 'sqlplus') . ' -L ' . shellescape(
        \ get(url, 'user', 'system') . '/' . get(url, 'password', 'oracle') .
        \ '@' . s:conn(url))
endfunction

function! db#adapter#oracle#filter(url) abort
  return substitute(db#adapter#oracle#interactive(a:url), ' -L ', ' -L -S ', '')
endfunction

function! db#adapter#oracle#auth_pattern() abort
  return 'ORA-01017'
endfunction

function! db#adapter#oracle#dbext(url) abort
  let url = db#url#parse(a:url)
  return {'srvname': s:conn(url), 'host': '', 'port': '', 'dbname': ''}
endfunction

function! db#adapter#oracle#tables(url)
  let l:names = split(system("echo 'set markup csv on;\nselect table_name from user_tables;' | " . db#adapter#oracle#interactive(a:url)), '\n')[12:-6]

  for l:i in range(len(l:names))
    let l:names[l:i] = l:names[l:i][1:-2]
  endfor

  return l:names
endfunction

function! db#adapter#oracle#massage(input) abort
  if a:input =~# ";\s*\n*$"
    return a:input
  endif
  return a:input . "\n;"
endfunction
