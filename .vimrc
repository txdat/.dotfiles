" vim
" config{{{
" disable builtin plugins
let builtin_plugins = [
    \'2html_plugin',
    \'bugreport',
    \'compiler',
    \'ftplugin',
    \'getscript',
    \'getscriptPlugin',
    \'gzip',
    \'logipat',
    \'man',
    \'matchit',
    \'matchparen',
    \'netrw',
    \'netrwFileHandlers',
    \'netrwPlugin',
    \'netrwSettings',
    \'osc52',
    \'optwin',
    \'rplugin',
    \'rrhelper',
    \'shada',
    \'spellfile',
    \'spellfile_plugin',
    \'synmenu',
    \'tar',
    \'tarPlugin',
    \'tohtml',
    \'tutor',
    \'vimball',
    \'vimballPlugin',
    \'zip',
    \'zipPlugin',
    \]

for plugin in builtin_plugins
    exe 'let g:loaded_' . plugin . '=1'
endfor

" ----------------------------------
" general
" ----------------------------------

set rtp^=~/.vim
set nocompatible " use vim defaults
" set clipboard^=unnamed,unnamedplus " system's clipboard
set timeout
set timeoutlen=300 " key mappings timeout
set noswapfile
set nobackup
set nowritebackup
set completeopt=menuone,noinsert,noselect " insert mode
set encoding=utf-8
set fileencoding=utf-8
set mouse=a " enable mouse support
set noerrorbells
set belloff=all
set bs=2 " backspacing in insert mode
set modelines=2
set wildmode=list:longest,list:full
set wildignore+=.git
set shortmess=I " disable vim intro
set laststatus=2 " always show statusline
set guicursor=n-v-c:block-Cursor " using block cursor
set guicursor+=i:block-iCursor
set guicursor+=n-v-c:blinkon0
set guicursor+=i:blinkon0
" set colorcolumn=80
set ruler " show cursor position
set fillchars=diff:\ 
set fillchars+=eob:\ 
set fillchars+=fold:\ 
set fillchars+=foldopen:-
set fillchars+=foldsep:│
set fillchars+=foldclose:+
set fillchars+=vert:\ 
" set listchars=eol:↴
" set list " show eol, ...
" set cursorline
set number " show line number
set relativenumber " (-1,+1) line number
set showmatch " highlight matching parenthesis
" set foldmethod=marker " enable folding
set signcolumn=auto
set splitright " vertical split to the right
set splitbelow " horizontal split to the bottom

let mapleader=' '
let maplocalleader='\'

" spelling
" set spelllang=en_us
" set spell

" ----------------------------------
" tabs, indent, ...
" ----------------------------------

set autoindent
set cindent
" set smartindent
set smarttab
set expandtab " use spaces instead of tab
set tabstop=2 " 1 tab = 2 spaces
set softtabstop=2
set shiftwidth=2 " shifts 2 spaces when using tab
set shiftround
set linebreak " wrap on word boundary
set textwidth=0

" ----------------------------------
" searching
" ----------------------------------

set hlsearch " highlight search result
set incsearch " show first match when start typing
set ignorecase " ignore case sensitive when searching
set smartcase " ignore lowercase for the whole pattern

" ----------------------------------
" cpu, memory
" ----------------------------------

set hidden " enable background buffers
set viminfo='20,\"50
set history=50
set lazyredraw " faster scrolling
set synmaxcol=240 " maximum column for syntax highligh
set updatetime=100 " milli-seconds to wait for trigger an event (keymap)

" ----------------------------------
" statusline
" ----------------------------------

augroup Statusline
    autocmd!
    autocmd WinEnter,BufEnter * let b:git_branch = system("git branch --show-current 2> /dev/null | tr -d '\n'")
augroup END

" set noshowmode
set statusline=
set statusline+=%1*\ [%{toupper(mode())}]\  " The current mode
set statusline+=%2*\ %<%f%m%r%h%w\          " File path, modified, readonly, helpfile, preview
set statusline+=%=                          " Right Side
set statusline+=%1*\ %{b:git_branch}        " Git branch
set statusline+=%2*\ \ %l:%v\ %3p%%         " Line:Col number, percentage of document
" set statusline+=%3*\ %{''.(&fenc!=''?&fenc:&enc).''}     " Encoding
" set statusline+=%4*\ (%{&ff})                            " FileFormat (dos/unix..)

" ----------------------------------
" colorscheme
" ----------------------------------

augroup Monokai
    autocmd!
    autocmd Colorscheme unokai call s:SetHighlights()
augroup END

function! s:SetHighlights()
    highlight Normal guifg=#eee8d5 guibg=#000000
    highlight NormalFloat guifg=#eee8d5 guibg=#111111
    highlight VertSplit guibg=NONE
    highlight StatusLine guifg=#eee8d5 guibg=#111111
    highlight StatusLineNC guifg=#eee8d5 guibg=#000000
endfunction

set termguicolors
filetype plugin indent on
syntax on
colorscheme unokai

" ----------------------------------
" autocommands
" ----------------------------------

" " highlight on yank (selected copy)
" function s:matchdelete(match, win)
"     silent! call matchdelete(a:match, a:win)
" endfunction
"
" function! s:FlashYankedText()
"     let match = matchadd('Visual',".\\%>'\\[\\_.*\\%<']..")
"     let win = win_getid()
"     call timer_start(500, {-> s:matchdelete(match, win)})
" endfunction
"
" augroup YankHighlight
"     autocmd!
"     autocmd TextYankPost * if v:event.operator == 'y' | call s:FlashYankedText() | endif
" augroup END

" remove whitespace on save
autocmd BufWritePre * :%s/\\s\\+$//e

" don't auto commenting new lines
autocmd BufEnter * set fo-=c fo-=r fo-=o

" open terminal
autocmd CmdlineEnter term :botright split term://$SHELL

" enter insert mode when switching to terminal
autocmd BufWinEnter if &buftype == 'terminal' | setlocal listchars= nonumber norelativenumber nocursorline | endif

" close terminal buffer on process exit
autocmd BufLeave * stopinsert

" ----------------------------------
" user commands
" ----------------------------------

command! -nargs=1 SetIndent execute printf("set tabstop=%s softtabstop=%s shiftwidth=%s", <args>, <args>, <args>)

command! -nargs=+ QfReplace call QfReplace(<f-args>)
function! QfReplace(...)
    execute printf('cfdo %%s/%s/%s/%s | update', a:1, a:2, get(a:,3,'g'))
endfunction

" ----------------------------------
" file type
" ----------------------------------

" Set filetype to helm for any yaml file inside a 'templates' folder
autocmd BufRead,BufNewFile */templates/*.yaml,*/templates/*.tpl set filetype=helm

"}}}

" keymaps{{{

nnoremap <silent> <A-q> q
nnoremap <silent> q <nop>

inoremap <silent> <F1> <nop>
nnoremap <silent> <F1> :set wrap!<CR>

nnoremap <silent> <F3> :set invpaste paste?<CR>
"set pastetoggle=<F3>

"nnoremap <silent> <F3> :setlocal spell! spell?<CR>
"nnoremap <silent> <C-l> [s1z=<C-o>
"inoremap <silent> <C-l> <C-g>u<ESC>[s1z=`]a<C-g>u

nnoremap <silent> DD "_dd

nnoremap <silent> H ^
nnoremap <silent> L $
nnoremap <silent> J <C-d>
nnoremap <silent> K <C-u>

nnoremap <silent> <A-v> :vsplit<CR>

nnoremap <silent> <C-t> :term<CR>
"tnoremap <silent> <Esc> <C-\><C-n>

nnoremap <silent> [t :tabprevious<CR>
nnoremap <silent> ]t :tabnext<CR>
nnoremap <silent> \t :tablast<CR>

nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> \b :b#<CR>

nnoremap <silent> <C-u> <nop>
nnoremap <silent> <C-d> :bd!<CR>
"nnoremap <silent> <C-S-d> :<C-U>bprevious <bar> bdelete #<CR>
nnoremap <silent> <C-q> :qa!<CR>

nnoremap <silent> <ESC> :nohl<CR>

nnoremap <silent> <C-s> :w<CR>
inoremap <silent> <C-s> <cmd>w<CR>
"inoremap <silent> <C-s> <C-c>:w<CR>
"nnoremap <silent> <C-S-s> :wa<CR>

nnoremap <silent> co :copen<CR>
nnoremap <silent> cq :cclose<CR>
nnoremap <silent> cc :call setqflist([])<CR>
nnoremap <silent> ]c :cnext<CR>
nnoremap <silent> [c :cprev<CR>

"vnoremap <silent> // y/\V<C-R>=escape(@",'/\')<CR><CR>
"tnoremap <expr> <C-r> '<C-\><C-N>"'.nr2char(getchar()).'pi'
"cnoremap <expr> <C-r><space> getcmdtype() =~ '[/?]' ? '.\{-}' : "<space>"

"vnoremap <silent> J :move '>+1<CR>gv=gv
"vnoremap <silent> K :move '<-2<CR>gv=gv

" nnoremap <silent> <F2> :%s/<C-r>"//g<Left><Left>
nnoremap <silent> <F2> :%s/\<<C-r><C-w>\>//g<Left><Left>

" duplicate a line and comment out the first line
nnoremap <silent> yc yy<cmd>normal gcc<CR>p

nnoremap <silent> <C-c> ciw

"nnoremap <silent> <C-j> :resize -2<CR>
"nnoremap <silent> <C-k> :resize +2<CR>
"nnoremap <silent> <C-h> :vertical resize -2<CR>
"nnoremap <silent> <C-l> :vertical resize +2<CR>
"}}}

" plugins{{{

packadd! editorconfig
packadd! comment

call plug#begin()

" Plug 'tpope/vim-surround'

" fzf{{{
Plug 'junegunn/fzf.vim'

let g:fzf_vim = {}
"let g:fzf_vim.command_prefix = 'Fzf'
"let g:fzf_layout = { 'window': { 'width': 1.0, 'height': 1.0, 'relative': v:true } }
let g:fzf_layout = { 'down': '100%' }

function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

let g:fzf_action = {
  \ 'ctrl-q': function('s:build_quickfix_list'),
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" overwrite fzf's functions
command! -bang -nargs=* Files call fzf#run(fzf#wrap(
  \   'fd
        \ --type f
        \ --color=always
        \ --hidden
        \ --follow
        \ --exclude .git
        \ '.shellescape(<q-args>),
  \   fzf#vim#with_preview({'options': '--preview "bat --color=always --style=numbers,changes {}"'}),
  \   <bang>0))

command! -bang -nargs=* Rg call fzf#vim#grep(
  \   'rg
        \ --color=always
        \ --hidden
        \ --follow
        \ --no-heading
        \ --with-filename
        \ --line-number
        \ --column
        \ --smart-case
        \ --glob "!.git/*"
        \ '.shellescape(<q-args>),
  \   fzf#vim#with_preview({'options': '--preview "bat --color=always --style=numbers,changes {}" --delimiter : --nth 4..'}),
  \   <bang>0)

nnoremap <silent> <leader>fs :GFiles?<CR>
nnoremap <silent> <leader>fc :BCommits<CR>
nnoremap <silent> <leader>ff :Files<CR>
nnoremap <silent> <leader>fg :Rg<CR>
nnoremap <silent> <leader>fb :Buffers<CR>
"}}}

" coc{{{
Plug 'neoclide/coc.nvim', {'branch': 'master', 'do': 'npm ci'}

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
" <c-space> to trigger completion
inoremap <silent><expr> <c-@> coc#refresh()

"nmap <silent> [d <Plug>(coc-diagnostic-prev)
"nmap <silent> ]d <Plug>(coc-diagnostic-next)
nmap <silent> [e <Plug>(coc-diagnostic-prev-error)
nmap <silent> ]e <Plug>(coc-diagnostic-next-error)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gt <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gn <Plug>(coc-rename)
xmap <silent> ga <Plug>(coc-codeaction-selected)
nmap <silent> ga <Plug>(coc-codeaction-selected)
" nmap <silent> <C-i> <Plug>(coc-format)

let g:coc_global_extensions = [
  \ 'coc-pairs',
  \ 'coc-json',
  \ 'coc-yaml',
  \ ]

hi! CocErrorSign guifg=#d75f5f
hi! CocErrorHighlight guifg=#d75f5f
hi! CocWarningSign guifg=#ffaf5f
hi! CocWarningHighlight guifg=#ffaf5f
"}}}

" ale{{{
Plug 'dense-analysis/ale'

let g:ale_linters_explicit = 1
let g:ale_fixers = {
      \   'c': ['clang-format'],
      \   'cpp': ['clang-format'],
      \   'cuda': ['clang-format'],
      \   'proto': ['clang-format'],
      \   'rust': ['rustfmt'],
      \   'go': ['gofmt'],
      \   'python': ['ruff_format'],
      \   'javascript': ['prettier'],
      \   'javascriptreact': ['prettier'],
      \   'typescript': ['prettier'],
      \   'typescriptreact': ['prettier'],
      \   'json': ['prettier'],
      \   'markdown': ['prettier'],
      \}

let g:ale_set_highlights = 0
let g:ale_floating_window_border = repeat([''], 8)
let g:ale_disable_lsp = 1

nmap <silent> <C-i> :ALEFix<CR>
"}}}

call plug#end()
"}}}
