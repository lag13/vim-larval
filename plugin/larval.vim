" Assignment regex's
augroup larval
    autocmd!
    autocmd FileType vim
                \ let b:larval_assignment_regex = '\v\s*let\s+(%(.:)=(.{-}))\s*\=\s*(([^|]*%(\n\s*\\.*)*))'
    autocmd FileType php
                \ let b:larval_assignment_regex = '\v\s*(\$(\k+)).{-}\=\s*((%(.|\n){-});)'
augroup END

" val_type c [1, 2, 3, 4] where:
" 1 - around lval
" 2 - inner lval
" 3 - around rval
" 4 - inner rval
function! s:larval(val_type)
    let assignment_regex = b:larval_assignment_regex
    let end_pos = searchpos(assignment_regex, 'ce')
    if !end_pos[0]
        let end_pos = searchpos(assignment_regex, 'bce')
    endif
    if end_pos[0]
        " Copy the entire assignment
        normal! v
        call search(assignment_regex, 'b')
        let saved_unnamed_register = @@
        normal! y
        let assignment = @@
        let @@ = saved_unnamed_register
        " Pull out the value we're interested in
        let value = '\V' . escape(substitute(assignment, assignment_regex, '\'.a:val_type, ''), '\')
        let value = substitute(value, '\n', '\\n', 'g')
        " Visually select the value
        if search(value, 'c')
            normal! v
            call search(value, 'e')
        endif
    endif
endfunction

onoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
xnoremap <silent> <Plug>LarvalAroundLval :<C-u>call <SID>larval(1)<CR>
onoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
xnoremap <silent> <Plug>LarvalInnerLval  :<C-u>call <SID>larval(2)<CR>
onoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
xnoremap <silent> <Plug>LarvalAroundRval :<C-u>call <SID>larval(3)<CR>
onoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>
xnoremap <silent> <Plug>LarvalInnerRval  :<C-u>call <SID>larval(4)<CR>

function! s:create_map(plug, around, is_lval)
    if !hasmapto(a:plug, 'ov')
        let lhs = (a:around ? 'a' : 'i') . (a:is_lval ? 'l' : 'r')
        for i in range(0, 1)
            if mapcheck(lhs, 'o') ==# ''
                execute "omap ".lhs." ".a:plug
                execute "xmap ".lhs." ".a:plug
                break
            endif
            let lhs = lhs . 'v'
        endfor
    endif
endfunction

if !exists('g:larval_no_mappings')
    call s:create_map('<Plug>LarvalAroundLval', 1, 1)
    call s:create_map('<Plug>LarvalInnerLval',  0, 1)
    call s:create_map('<Plug>LarvalAroundRval', 1, 0)
    call s:create_map('<Plug>LarvalInnerRval',  0, 0)
endif

