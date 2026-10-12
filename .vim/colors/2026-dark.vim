" 2026-dark.vim — Dark colorscheme
" Monokai, with the editor background overridden to black (#121314).
" Palette: Monokai (Wimer Hazenberg); group mapping follows sickill/vim-monokai (MIT)
" License: MIT
"
" Monokai palette:
"   background #272822   lineHighlight #3c3d37   selection #49483e
"   foreground #f8f8f2   comment #75715e         lineNr #90908a
"   pink #f92672   orange #fd971f   yellow #e6db74
"   green #a6e22e  blue #66d9ef     purple #ae81ff   white #f8f8f0
"
" Local overrides / mapping:
"   editor.background   #121314  (black, overrides #272822)
"   text                #f8f8f2
"   comment             #75715e
"   constant/number     #ae81ff  (purple)
"   string              #e6db74  (yellow)
"   identifier          #66d9ef  (blue)
"   function            #a6e22e  (green)
"   statement/keyword   #f92672  (pink)
"   storage/type        #66d9ef / #f92672
"   tag                 #f92672  (pink)

set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "2026-dark"

" ============================================================
" Core UI
" ============================================================
hi Normal         guifg=#f8f8f2 guibg=#121314   ctermfg=231 ctermbg=233
hi NormalNC       guifg=#f8f8f2 guibg=#272822   ctermfg=231 ctermbg=235
hi NormalFloat    guifg=#f8f8f2 guibg=#272822   ctermfg=231 ctermbg=235

hi Cursor         guifg=#272822 guibg=#f8f8f0   ctermfg=235 ctermbg=221
hi CursorLine     guibg=#3c3d37 ctermbg=237 gui=NONE cterm=NONE
hi CursorLineNr   guifg=#f8f8f2 guibg=#3c3d37   ctermfg=231 ctermbg=237  gui=NONE cterm=NONE
hi CursorColumn   guibg=#3c3d37 ctermbg=237

hi LineNr         guifg=#90908a guibg=#121314   ctermfg=102 ctermbg=233
hi SignColumn     guifg=#90908a guibg=#121314   ctermfg=102 ctermbg=233
hi FoldColumn     guifg=#90908a guibg=#121314   ctermfg=102 ctermbg=233
hi Folded         guifg=#75715e guibg=#272822   ctermfg=242 ctermbg=235  gui=italic

hi Visual         term=NONE guifg=NONE guibg=#49483e   ctermfg=NONE ctermbg=59  gui=NONE cterm=NONE
hi VisualNOS      term=NONE guifg=NONE guibg=#49483e   ctermfg=NONE ctermbg=59  gui=NONE cterm=NONE

hi StatusLine     guifg=#f8f8f2 guibg=#64645e   ctermfg=231 ctermbg=241  gui=bold
hi StatusLineNC   guifg=#f8f8f2 guibg=#64645e   ctermfg=231 ctermbg=241
hi WinSeparator   guifg=#64645e guibg=NONE      ctermfg=241
hi VertSplit      guifg=#64645e guibg=NONE      ctermfg=241

hi TabLine        guifg=#90908a guibg=#272822   ctermfg=102 ctermbg=235  gui=NONE cterm=NONE
hi TabLineSel     guifg=#f8f8f2 guibg=#121314   ctermfg=231 ctermbg=233  gui=bold
hi TabLineFill    guibg=#272822 ctermbg=235

hi Pmenu          guifg=#f8f8f2 guibg=#272822   ctermfg=231 ctermbg=235
hi PmenuSel       guifg=#f8f8f2 guibg=#49483e   ctermfg=231 ctermbg=59   gui=bold
hi PmenuSbar      guibg=#3c3d37 ctermbg=237
hi PmenuThumb     guibg=#64645e ctermbg=241

hi Search         guifg=#f8f8f2 guibg=#204a87   ctermfg=231 ctermbg=24
hi CurSearch      guifg=#272822 guibg=#e6db74   ctermfg=235 ctermbg=186   gui=bold
hi IncSearch      guifg=#272822 guibg=#e6db74   ctermfg=235 ctermbg=186   gui=bold
hi Substitute     guifg=#272822 guibg=#fd971f   ctermfg=235 ctermbg=208

hi MatchParen     guifg=#f92672 guibg=#49483e   ctermfg=197 ctermbg=59   gui=bold

hi QuickFixLine   guibg=#49483e ctermbg=59

hi ColorColumn    guibg=#3c3d37 ctermbg=237
hi Conceal        guifg=#f8f8f0 ctermfg=221

hi NonText        guifg=#75715e ctermfg=242
hi SpecialKey     guifg=#75715e ctermfg=242
hi Whitespace     guifg=#3c3d37 ctermfg=237

hi Title          guifg=#f8f8f2 ctermfg=231     gui=bold
hi Question       guifg=#66d9ef ctermfg=81
hi MoreMsg        guifg=#66d9ef ctermfg=81
hi ModeMsg        guifg=#f8f8f2 ctermfg=231     gui=bold
hi ErrorMsg       guifg=#f8f8f0 guibg=#f92672   ctermfg=221 ctermbg=197  gui=bold
hi WarningMsg     guifg=#fd971f ctermfg=208

hi WildMenu       guifg=#272822 guibg=#a6e22e   ctermfg=235 ctermbg=148   gui=bold

hi Directory      guifg=#ae81ff ctermfg=141
hi EndOfBuffer    guifg=#75715e ctermfg=242

" ============================================================
" Syntax
" ============================================================
hi Comment        guifg=#75715e ctermfg=242     gui=italic  cterm=italic
hi SpecialComment guifg=#75715e ctermfg=242     gui=italic  cterm=italic

hi Constant       guifg=#ae81ff ctermfg=141
hi String         guifg=#e6db74 ctermfg=186
hi Character      guifg=#ae81ff ctermfg=141
hi Number         guifg=#ae81ff ctermfg=141
hi Boolean        guifg=#ae81ff ctermfg=141
hi Float          guifg=#ae81ff ctermfg=141

hi Identifier     guifg=#66d9ef ctermfg=81
hi Function       guifg=#a6e22e ctermfg=148

hi Statement      guifg=#f92672 ctermfg=197
hi Conditional    guifg=#f92672 ctermfg=197
hi Repeat         guifg=#f92672 ctermfg=197
hi Label          guifg=#e6db74 ctermfg=186
hi Operator       guifg=#f92672 ctermfg=197
hi Keyword        guifg=#f92672 ctermfg=197
hi Exception      guifg=#f92672 ctermfg=197

hi PreProc        guifg=#f92672 ctermfg=197
hi Include        guifg=#f92672 ctermfg=197
hi Define         guifg=#f92672 ctermfg=197
hi Macro          guifg=#f92672 ctermfg=197
hi PreCondit      guifg=#f92672 ctermfg=197

hi Type           guifg=#f92672 ctermfg=197
hi StorageClass   guifg=#66d9ef ctermfg=81
hi Structure      guifg=#66d9ef ctermfg=81
hi Typedef        guifg=#66d9ef ctermfg=81

hi Special        guifg=#f8f8f2 ctermfg=231
hi SpecialChar    guifg=#ae81ff ctermfg=141
hi Tag            guifg=#f92672 ctermfg=197
hi Delimiter      guifg=#f8f8f2 ctermfg=231
hi Debug          guifg=#f92672 ctermfg=197

hi Underlined     guifg=#66d9ef ctermfg=81     gui=underline cterm=underline
hi Ignore         guifg=#75715e ctermfg=242
hi Error          guifg=#f8f8f0 guibg=#f92672   ctermfg=221 ctermbg=197  gui=bold
hi Todo           guifg=#272822 guibg=#75715e   ctermfg=235 ctermbg=242  gui=bold cterm=bold

" ============================================================
" Diffs
" ============================================================
hi DiffAdd        guifg=#f8f8f2 guibg=#46830c   ctermfg=231 ctermbg=64
hi DiffChange     guifg=#f8f8f2 guibg=#243955   ctermfg=231 ctermbg=237
hi DiffDelete     guifg=#8b0807  ctermfg=88
hi DiffText       guifg=#f8f8f2 guibg=#204a87   ctermfg=231 ctermbg=24   gui=bold

hi diffAdded      guifg=#a6e22e ctermfg=148
hi diffRemoved    guifg=#f92672 ctermfg=197
hi diffChanged    guifg=#e6db74 ctermfg=186
hi diffFile       guifg=#66d9ef ctermfg=81     gui=bold
hi diffLine       guifg=#66d9ef ctermfg=81     gui=bold

" ============================================================
" Spell checking
" ============================================================
hi SpellBad       guisp=#f92672  gui=undercurl  cterm=underline ctermfg=197
hi SpellCap       guisp=#66d9ef  gui=undercurl  cterm=underline ctermfg=81
hi SpellLocal     guisp=#a6e22e  gui=undercurl  cterm=underline ctermfg=148
hi SpellRare      guisp=#ae81ff  gui=undercurl  cterm=underline ctermfg=141

" ============================================================
" LSP / Diagnostics (Neovim)
" ============================================================
hi DiagnosticError         guifg=#f92672 ctermfg=197
hi DiagnosticWarn          guifg=#fd971f ctermfg=208
hi DiagnosticInfo          guifg=#66d9ef ctermfg=81
hi DiagnosticHint          guifg=#a6e22e ctermfg=148
hi DiagnosticOk            guifg=#a6e22e ctermfg=148
hi DiagnosticUnderlineError    guisp=#f92672 gui=undercurl cterm=underline
hi DiagnosticUnderlineWarn     guisp=#fd971f gui=undercurl cterm=underline
hi DiagnosticUnderlineInfo     guisp=#66d9ef gui=undercurl cterm=underline
hi DiagnosticUnderlineHint     guisp=#a6e22e gui=undercurl cterm=underline
hi DiagnosticVirtualTextError  guifg=#f92672 guibg=#272822 ctermfg=197 ctermbg=235
hi DiagnosticVirtualTextWarn   guifg=#fd971f guibg=#272822 ctermfg=208 ctermbg=235
hi DiagnosticVirtualTextInfo   guifg=#66d9ef guibg=#272822 ctermfg=81  ctermbg=235
hi DiagnosticVirtualTextHint   guifg=#a6e22e guibg=#272822 ctermfg=148 ctermbg=235

" ============================================================
" Treesitter highlight groups (Neovim 0.8+ only)
" ============================================================
if has('nvim')
  hi! link @comment                Comment
  hi! link @comment.documentation  SpecialComment
  hi! link @keyword                Keyword
  hi! link @keyword.function       Keyword
  hi! link @keyword.operator       Operator
  hi! link @keyword.return         Keyword
  hi! link @function               Function
  hi! link @function.call          Function
  hi! link @function.builtin       Special
  hi! link @method                 Function
  hi! link @method.call            Function
  hi! link @constructor            Function
  hi! link @parameter              Identifier
  hi! link @variable               Identifier
  hi! link @variable.builtin       Special
  hi! link @variable.other         Delimiter
  hi! link @constant               Constant
  hi! link @constant.builtin       Constant
  hi! link @constant.macro         Macro
  hi! link @string                 String
  hi! link @string.escape          SpecialChar
  hi! link @string.special         SpecialChar
  hi! link @character              Character
  hi! link @number                 Number
  hi! link @float                  Float
  hi! link @boolean                Boolean
  hi! link @type                   Type
  hi! link @type.builtin           Type
  hi! link @type.definition        Typedef
  hi! link @attribute              PreProc
  hi! link @field                  Identifier
  hi! link @property               Special
  hi! link @namespace              Directory
  hi! link @include                Include
  hi! link @operator               Operator
  hi! link @punctuation            Delimiter
  hi! link @tag                    Tag
  hi! link @tag.attribute          Special
  hi! link @tag.delimiter          Delimiter
endif

" ============================================================
" Git signs / Gutter markers
" ============================================================
hi GitSignsAdd     guifg=#a6e22e guibg=#121314 ctermfg=148 ctermbg=233
hi GitSignsChange  guifg=#e6db74 guibg=#121314 ctermfg=186 ctermbg=233
hi GitSignsDelete  guifg=#f92672 guibg=#121314 ctermfg=197 ctermbg=233

" ============================================================
" Neovim-specific
" ============================================================
hi FloatBorder    guifg=#49483e guibg=#272822 ctermfg=59 ctermbg=235
hi FloatTitle     guifg=#f8f8f2 guibg=#272822 ctermfg=231 ctermbg=235 gui=bold
hi WinBar         guifg=#f8f8f2 guibg=#272822 ctermfg=231 ctermbg=235 gui=bold
hi WinBarNC       guifg=#75715e guibg=#272822 ctermfg=242 ctermbg=235

" Telescope
hi TelescopeNormal         guibg=#272822
hi TelescopeBorder         guifg=#49483e guibg=#272822
hi TelescopeSelection      guibg=#49483e guifg=#f8f8f2
hi TelescopeSelectionCaret guifg=#66d9ef guibg=#272822
hi TelescopeMatching       guifg=#a6e22e gui=bold

" ============================================================
" coc.nvim
" ============================================================
hi! link CocMenuSel        PmenuSel
hi! link CocPumMenu        Pmenu
hi! link CocPumSearch      IncSearch
hi! link CocPumDetail      NormalFloat
hi! link CocPumVirtualText Comment

hi CocFloating        guifg=#f8f8f2 guibg=#272822   ctermfg=231 ctermbg=235
hi! link CocFloatThumb    PmenuThumb
hi! link CocFloatSbar     PmenuSbar
hi CocFloatDividingLine   guifg=#49483e ctermfg=59

hi CocErrorSign         guifg=#f92672 guibg=#121314 ctermfg=197 ctermbg=233
hi CocWarningSign       guifg=#fd971f guibg=#121314 ctermfg=208 ctermbg=233
hi CocInfoSign          guifg=#66d9ef guibg=#121314 ctermfg=81  ctermbg=233
hi CocHintSign          guifg=#a6e22e guibg=#121314 ctermfg=148 ctermbg=233

hi CocErrorVirtualText  guifg=#f92672 guibg=#272822 ctermfg=197 ctermbg=235  gui=italic cterm=italic
hi CocWarningVirtualText guifg=#fd971f guibg=#272822 ctermfg=208 ctermbg=235  gui=italic cterm=italic
hi CocInfoVirtualText   guifg=#66d9ef guibg=#272822 ctermfg=81  ctermbg=235  gui=italic cterm=italic
hi CocHintVirtualText   guifg=#a6e22e guibg=#272822 ctermfg=148 ctermbg=235  gui=italic cterm=italic

hi CocErrorHighlight    guisp=#f92672 gui=undercurl  cterm=underline
hi CocWarningHighlight  guisp=#fd971f gui=undercurl  cterm=underline
hi CocInfoHighlight     guisp=#66d9ef gui=undercurl  cterm=underline
hi CocHintHighlight     guisp=#a6e22e gui=undercurl  cterm=underline

hi CocDeprecatedHighlight guisp=#75715e gui=strikethrough cterm=strikethrough
hi CocUnusedHighlight     guifg=#75715e               ctermfg=242
hi CocCodeLens            guifg=#75715e ctermfg=242   gui=italic cterm=italic

hi CocHighlightText   guibg=#272822 ctermbg=235
hi CocHighlightRead   guibg=#272822 ctermbg=235
hi CocHighlightWrite  guibg=#272822   ctermbg=235

hi CocInlayHint           guifg=#75715e guibg=#272822 ctermfg=242 ctermbg=235 gui=italic cterm=italic
hi CocInlayHintType       guifg=#66d9ef guibg=#272822 ctermfg=81 ctermbg=235 gui=italic cterm=italic
hi CocInlayHintParameter  guifg=#fd971f guibg=#272822 ctermfg=208 ctermbg=235 gui=italic cterm=italic

hi! link CocSemClass        Type
hi! link CocSemStruct       Type
hi! link CocSemInterface    Type
hi! link CocSemEnum         Type
hi! link CocSemEnumMember   Constant
hi! link CocSemType         Type
hi! link CocSemTypeParameter Type
hi! link CocSemNamespace    Directory
hi! link CocSemFunction     Function
hi! link CocSemMethod       Function
hi! link CocSemProperty     Special
hi! link CocSemVariable     Identifier
hi! link CocSemParameter    Identifier
hi! link CocSemKeyword      Keyword
hi! link CocSemMacro        Macro
hi! link CocSemString       String
hi! link CocSemNumber       Number
hi! link CocSemBoolean      Boolean
hi! link CocSemOperator     Operator
hi! link CocSemComment      Comment
hi CocSemDeprecated         guisp=#75715e gui=strikethrough cterm=strikethrough
hi CocSemModification       guifg=#e6db74 ctermfg=186

hi CocListMode     guifg=#f8f8f2 guibg=#272822   ctermfg=231 ctermbg=235  gui=bold
hi CocListPath     guifg=#75715e guibg=#272822   ctermfg=242 ctermbg=235
hi CocListSearch   guifg=#272822 guibg=#66d9ef   ctermfg=235 ctermbg=81   gui=bold
hi! link CocListLine    CursorLine
hi! link CocListSelected PmenuSel

hi CocTreeTitle       guifg=#f8f8f2 ctermfg=231 gui=bold
hi CocTreeDescription guifg=#75715e ctermfg=242
hi CocTreeOpenClose   guifg=#75715e ctermfg=242
hi! link CocTreeSelected CursorLine

hi CocGitAddedSign         guifg=#a6e22e guibg=#121314 ctermfg=148 ctermbg=233
hi CocGitChangedSign       guifg=#e6db74 guibg=#121314 ctermfg=186 ctermbg=233
hi CocGitRemovedSign       guifg=#f92672 guibg=#121314 ctermfg=197 ctermbg=233
hi CocGitTopRemovedSign    guifg=#f92672 guibg=#121314 ctermfg=197 ctermbg=233
hi CocGitChangeRemovedSign guifg=#e6db74 guibg=#121314 ctermfg=186 ctermbg=233
hi CocGitBlame             guifg=#75715e ctermfg=242 gui=italic cterm=italic

hi CocSnippetVisual   guibg=#3c3d37 ctermbg=237

" vim: ft=vim
