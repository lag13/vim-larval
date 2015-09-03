augroup larval
    autocmd!
    autocmd FileType php
                \ let b:larval_lval_regex = '\s*\$\zs[^=]\+\ze=' |
                \ let b:larval_rval_start = '=\s*\zs' |
                \ let b:larval_rval_end = '.\ze;' |
    autocmd FileType vim
                \ let b:larval_lval_regex = 'let\s*\zs[^=]\+\ze=' |
                \ let b:larval_rval_start = '=\s*\zs' |
                \ let b:larval_rval_end = '.\ze$' |
                \ let b:larval_rval_linecontinuation = '\s*\\'
augroup END

function! s:lValue()
    if s:insideRval([line('.'), col('.')])
        let [start_rval, not_used] = s:getStartEndRval(1)
    else
        let [start_rval, not_used] = s:getStartEndRval(0)
    endif
    call cursor(start_rval)
    call search(b:larval_lval_regex, 'b')
    normal! v
    call search(b:larval_lval_regex, 'e')
    if match(getline('.')[col('.')-1], '\s') != -1
        normal! ge
    endif
endfunction
onoremap <silent> ilv :<C-u>call <SID>lValue()<CR>
xnoremap <silent> ilv :<C-u>call <SID>lValue()<CR>

function! s:rValue()
    if s:insideRval([line('.'), col('.')])
        let [start_rval, end_rval] = s:getStartEndRval(1)
    else
        let [start_rval, end_rval] = s:getStartEndRval(0)
    endif
    call cursor(start_rval)
    normal! v
    call cursor(end_rval)
endfunction
onoremap <silent> ir :<C-u>call <SID>rValue()<CR>
xnoremap <silent> ir :<C-u>call <SID>rValue()<CR>

function! s:insideRval(pos)
    let [start_rval, end_rval] = s:getStartEndRval(1)
    if start_rval == end_rval
        return start_rval[1] <= a:pos[1] && a:pos[1] <= end_rval[1]
    else
        return start_rval[0] <= a:pos[0] && a:pos[0] <= end_rval[0]
    endif
endfunction

function! s:getStartEndRval(prev_rval)
    let w = winsaveview()
    let start = searchpos(b:larval_rval_start, a:prev_rval ? 'bc' : '')
    let linecontinuation = exists('b:larval_rval_linecontinuation') ? b:larval_rval_linecontinuation : ''
    if linecontinuation !=# ''
        let next_line = line('.') + 1
        while match(getline(next_line), linecontinuation) != -1
            let next_line += 1
        endwhile
        call cursor(next_line-1, 1)
    endif
    let end = searchpos(b:larval_rval_end)
    call winrestview(w)
    return [start, end]
endfunction

