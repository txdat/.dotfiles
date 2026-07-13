" 2026-light.vim — Light colorscheme
" Converted from VSCode 2026 Light theme
" Source: microsoft/vscode extensions/theme-defaults/themes/2026-light.json
" License: MIT
"
" Palette (extracted from tokenColors + editor colors):
"
"   editor.background          #FFFFFF
"   editor.foreground          #202020
"   editorLineNumber.fg        #606060
"   editorLineNumber.activeFg  #202020
"   editor.lineHighlight       #EAEAEA (blended, ~#FAFAFA)
"   editor.selection           #0069CC40 -> blended over white #BFD9F2
"   editor.findMatch           #0069CC40 -> blended over white #BFD9F2
"   editorBracketMatch         #0069CC40 -> blended over white #BFD9F2
"   editorWidget.background    #FAFAFD
"   sidebar/panel background   #FAFAFD
"   border                     #E2E2E5
"   statusBar.background       #FAFAFD
"   statusBar.foreground       #606060
"
"   Token colors:
"   comment        #6e7781
"   constant       #0550ae
"   string         #0a3069
"   keyword        #cf222e
"   storage        #cf222e
"   entity.name    #953800  (class/var/definition)
"   entity.fn      #8250df
"   entity.tag     #116329
"   variable       #953800
"   variable.other #1f2328
"   support        #0550ae
"   invalid        #82071e
"   markup.deleted #82071e
"   markup.inserted#116329
"   markup.changed #953800
"   foreground-dim #1f2328
"
"   UI accents:
"   blue-accent    #0069CC
"   error          #ad0707
"   warning        #667309
"   git.added      #587c0c
"   git.modified   #667309
"   git.deleted    #ad0707
"
"   Vim-only derived shades (no direct VSCode key; chosen for readability):
"   whitespace-dim #DDDDDD, disabled-fg #BBBBBB, diag/coc tint backgrounds
"   blended from the accent/warning/error colors above.

set background=light
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "2026-light"

" ============================================================
" Core UI
" ============================================================
hi Normal         guifg=#202020 guibg=#FFFFFF   ctermfg=234 ctermbg=231
hi NormalNC       guifg=#202020 guibg=#FAFAFD   ctermfg=234 ctermbg=231
hi NormalFloat    guifg=#202020 guibg=#FAFAFD   ctermfg=234 ctermbg=231

hi Cursor         guifg=#FFFFFF guibg=#202020   ctermfg=231 ctermbg=234
hi CursorLine     guibg=#FAFAFA ctermbg=231 gui=NONE cterm=NONE
hi CursorLineNr   guifg=#202020 guibg=#FAFAFA   ctermfg=234 ctermbg=231  gui=NONE cterm=NONE
hi CursorColumn   guibg=#FAFAFA ctermbg=231

hi LineNr         guifg=#606060 guibg=#FFFFFF   ctermfg=241 ctermbg=231
hi SignColumn     guifg=#606060 guibg=#FFFFFF   ctermfg=241 ctermbg=231
hi FoldColumn     guifg=#606060 guibg=#FFFFFF   ctermfg=241 ctermbg=231
hi Folded         guifg=#606060 guibg=#EAEAEA   ctermfg=241 ctermbg=254  gui=italic

hi Visual         guibg=#BFD9F2  ctermbg=153
hi VisualNOS      guibg=#BFD9F2  ctermbg=153

hi StatusLine     guifg=#202020 guibg=#E2E2E5   ctermfg=234 ctermbg=253  gui=bold
hi StatusLineNC   guifg=#606060 guibg=#FAFAFD   ctermfg=241 ctermbg=231
hi WinSeparator   guifg=#E2E2E5 guibg=NONE      ctermfg=253
hi VertSplit      guifg=#E2E2E5 guibg=NONE      ctermfg=253

hi TabLine        guifg=#606060 guibg=#FAFAFD   ctermfg=241 ctermbg=231  gui=NONE cterm=NONE
hi TabLineSel     guifg=#202020 guibg=#FFFFFF   ctermfg=234 ctermbg=231  gui=bold
hi TabLineFill    guibg=#FAFAFD ctermbg=231

hi Pmenu          guifg=#202020 guibg=#FAFAFD   ctermfg=234 ctermbg=231
hi PmenuSel       guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold
hi PmenuSbar      guibg=#E2E2E5 ctermbg=253
hi PmenuThumb     guibg=#646464 ctermbg=241

hi Search         guifg=#202020 guibg=#BFD9F2   ctermfg=234 ctermbg=153
hi CurSearch      guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold
hi IncSearch      guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold
hi Substitute     guifg=#FFFFFF guibg=#953800   ctermfg=231 ctermbg=94

hi MatchParen     guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold

hi QuickFixLine   guibg=#0069CC ctermbg=26

hi ColorColumn    guibg=#EAEAEA ctermbg=254
hi Conceal        guifg=#606060 ctermfg=241

hi NonText        guifg=#BBBBBB ctermfg=249
hi SpecialKey     guifg=#BBBBBB ctermfg=249
hi Whitespace     guifg=#DDDDDD ctermfg=253

hi Title          guifg=#0550ae ctermfg=25      gui=bold
hi Question       guifg=#0069CC ctermfg=26
hi MoreMsg        guifg=#0069CC ctermfg=26
hi ModeMsg        guifg=#202020 ctermfg=234     gui=bold
hi ErrorMsg       guifg=#FFFFFF guibg=#ad0707   ctermfg=231 ctermbg=124  gui=bold
hi WarningMsg     guifg=#667309 ctermfg=58

hi WildMenu       guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold

hi Directory      guifg=#0550ae ctermfg=25
hi EndOfBuffer    guifg=#DDDDDD ctermfg=253

" ============================================================
" Syntax
" ============================================================
hi Comment        guifg=#6e7781 ctermfg=66      gui=italic  cterm=italic
hi SpecialComment guifg=#6e7781 ctermfg=66      gui=italic  cterm=italic

hi Constant       guifg=#0550ae ctermfg=25
hi String         guifg=#0a3069 ctermfg=23
hi Character      guifg=#cf222e ctermfg=160
hi Number         guifg=#0550ae ctermfg=25
hi Boolean        guifg=#0550ae ctermfg=25
hi Float          guifg=#0550ae ctermfg=25

hi Identifier     guifg=#953800 ctermfg=94
hi Function       guifg=#8250df ctermfg=98

hi Statement      guifg=#cf222e ctermfg=160
hi Conditional    guifg=#cf222e ctermfg=160
hi Repeat         guifg=#cf222e ctermfg=160
hi Label          guifg=#cf222e ctermfg=160
hi Operator       guifg=#cf222e ctermfg=160
hi Keyword        guifg=#cf222e ctermfg=160
hi Exception      guifg=#cf222e ctermfg=160

hi PreProc        guifg=#cf222e ctermfg=160
hi Include        guifg=#cf222e ctermfg=160
hi Define         guifg=#cf222e ctermfg=160
hi Macro          guifg=#cf222e ctermfg=160
hi PreCondit      guifg=#cf222e ctermfg=160

hi Type           guifg=#0550ae ctermfg=25
hi StorageClass   guifg=#cf222e ctermfg=160
hi Structure      guifg=#0550ae ctermfg=25
hi Typedef        guifg=#0550ae ctermfg=25

hi Special        guifg=#953800 ctermfg=94
hi SpecialChar    guifg=#116329 ctermfg=22
hi Tag            guifg=#116329 ctermfg=22
hi Delimiter      guifg=#1f2328 ctermfg=234
hi Debug          guifg=#82071e ctermfg=88

hi Underlined     guifg=#0550ae ctermfg=25      gui=underline cterm=underline
hi Ignore         guifg=#BBBBBB ctermfg=249
hi Error          guifg=#FFFFFF guibg=#ad0707   ctermfg=231 ctermbg=124  gui=bold
hi Todo           guifg=#FFFFFF guibg=#953800   ctermfg=231 ctermbg=94   gui=bold

" ============================================================
" Diffs
" ============================================================
hi DiffAdd        guifg=#116329 guibg=#dafbe1   ctermfg=22  ctermbg=194
hi DiffChange     guifg=#953800 guibg=#ffd8b5   ctermfg=94  ctermbg=223
hi DiffDelete     guifg=#82071e guibg=#ffebe9   ctermfg=88  ctermbg=224  gui=bold
hi DiffText       guifg=#953800 guibg=#ffd8b5   ctermfg=94  ctermbg=223  gui=bold

hi diffAdded      guifg=#587c0c ctermfg=64
hi diffRemoved    guifg=#ad0707 ctermfg=124
hi diffChanged    guifg=#667309 ctermfg=58
hi diffFile       guifg=#0550ae ctermfg=25      gui=bold
hi diffLine       guifg=#8250df ctermfg=98      gui=bold

" ============================================================
" Spell checking
" ============================================================
hi SpellBad       guisp=#ad0707  gui=undercurl  cterm=underline ctermfg=124
hi SpellCap       guisp=#0069CC  gui=undercurl  cterm=underline ctermfg=26
hi SpellLocal     guisp=#0550ae  gui=undercurl  cterm=underline ctermfg=25
hi SpellRare      guisp=#667309  gui=undercurl  cterm=underline ctermfg=58

" ============================================================
" LSP / Diagnostics (Neovim)
" ============================================================
hi DiagnosticError         guifg=#ad0707 ctermfg=124
hi DiagnosticWarn          guifg=#667309 ctermfg=58
hi DiagnosticInfo          guifg=#0069CC ctermfg=26
hi DiagnosticHint          guifg=#0550ae ctermfg=25
hi DiagnosticOk            guifg=#116329 ctermfg=22
hi DiagnosticUnderlineError    guisp=#ad0707 gui=undercurl cterm=underline
hi DiagnosticUnderlineWarn     guisp=#667309 gui=undercurl cterm=underline
hi DiagnosticUnderlineInfo     guisp=#0069CC gui=undercurl cterm=underline
hi DiagnosticUnderlineHint     guisp=#0550ae gui=undercurl cterm=underline
hi DiagnosticVirtualTextError  guifg=#ad0707 guibg=#FDEDED ctermfg=124 ctermbg=231
hi DiagnosticVirtualTextWarn   guifg=#667309 guibg=#FDF6E3 ctermfg=58  ctermbg=230
hi DiagnosticVirtualTextInfo   guifg=#0069CC guibg=#E6F2FA ctermfg=26  ctermbg=195
hi DiagnosticVirtualTextHint   guifg=#0550ae guibg=#EFF5FC ctermfg=25  ctermbg=231

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
hi GitSignsAdd     guifg=#587c0c guibg=#FFFFFF ctermfg=64  ctermbg=231
hi GitSignsChange  guifg=#667309 guibg=#FFFFFF ctermfg=58  ctermbg=231
hi GitSignsDelete  guifg=#ad0707 guibg=#FFFFFF ctermfg=124 ctermbg=231

" ============================================================
" Neovim-specific
" ============================================================
hi FloatBorder    guifg=#E2E2E5 guibg=#FAFAFD ctermfg=253 ctermbg=231
hi FloatTitle     guifg=#202020 guibg=#FAFAFD ctermfg=234 ctermbg=231 gui=bold
hi WinBar         guifg=#202020 guibg=#FAFAFD ctermfg=234 ctermbg=231 gui=bold
hi WinBarNC       guifg=#606060 guibg=#FAFAFD ctermfg=241 ctermbg=231

" Telescope
hi TelescopeNormal         guibg=#FAFAFD
hi TelescopeBorder         guifg=#E2E2E5 guibg=#FAFAFD
hi TelescopeSelection      guibg=#E5F0FA guifg=#202020
hi TelescopeSelectionCaret guifg=#0069CC guibg=#FAFAFD
hi TelescopeMatching       guifg=#0069CC gui=bold

" ============================================================
" coc.nvim
" ============================================================
hi! link CocMenuSel        PmenuSel
hi! link CocPumMenu        Pmenu
hi! link CocPumSearch      IncSearch
hi! link CocPumDetail      NormalFloat
hi! link CocPumVirtualText Comment

hi CocFloating        guifg=#202020 guibg=#FAFAFD   ctermfg=234 ctermbg=231
hi! link CocFloatThumb    PmenuThumb
hi! link CocFloatSbar     PmenuSbar
hi CocFloatDividingLine   guifg=#E2E2E5 ctermfg=253

hi CocErrorSign         guifg=#ad0707 guibg=#FFFFFF ctermfg=124 ctermbg=231
hi CocWarningSign       guifg=#667309 guibg=#FFFFFF ctermfg=58  ctermbg=231
hi CocInfoSign          guifg=#0069CC guibg=#FFFFFF ctermfg=26  ctermbg=231
hi CocHintSign          guifg=#0550ae guibg=#FFFFFF ctermfg=25  ctermbg=231

hi CocErrorVirtualText  guifg=#ad0707 guibg=#FDEDED ctermfg=124 ctermbg=231  gui=italic cterm=italic
hi CocWarningVirtualText guifg=#667309 guibg=#FDF6E3 ctermfg=58  ctermbg=230  gui=italic cterm=italic
hi CocInfoVirtualText   guifg=#0069CC guibg=#E6F2FA ctermfg=26  ctermbg=195  gui=italic cterm=italic
hi CocHintVirtualText   guifg=#0550ae guibg=#EFF5FC ctermfg=25  ctermbg=231  gui=italic cterm=italic

hi CocErrorHighlight    guisp=#ad0707 gui=undercurl  cterm=underline
hi CocWarningHighlight  guisp=#667309 gui=undercurl  cterm=underline
hi CocInfoHighlight     guisp=#0069CC gui=undercurl  cterm=underline
hi CocHintHighlight     guisp=#0550ae gui=undercurl  cterm=underline

hi CocDeprecatedHighlight guisp=#6e7781 gui=strikethrough cterm=strikethrough
hi CocUnusedHighlight     guifg=#6e7781               ctermfg=66
hi CocCodeLens            guifg=#606060 ctermfg=241   gui=italic cterm=italic

hi CocHighlightText   guibg=#E5F0FA ctermbg=195
hi CocHighlightRead   guibg=#E5F0FA ctermbg=195
hi CocHighlightWrite  guibg=#ffd8b5   ctermbg=223

hi CocInlayHint           guifg=#606060 guibg=#FAFAFD ctermfg=241 ctermbg=231 gui=italic cterm=italic
hi CocInlayHintType       guifg=#0550ae guibg=#FAFAFD ctermfg=25  ctermbg=231 gui=italic cterm=italic
hi CocInlayHintParameter  guifg=#953800 guibg=#FAFAFD ctermfg=94  ctermbg=231 gui=italic cterm=italic

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
hi CocSemDeprecated         guisp=#6e7781 gui=strikethrough cterm=strikethrough
hi CocSemModification       guifg=#667309 ctermfg=58

hi CocListMode     guifg=#202020 guibg=#E2E2E5   ctermfg=234 ctermbg=253  gui=bold
hi CocListPath     guifg=#606060 guibg=#E2E2E5   ctermfg=241 ctermbg=253
hi CocListSearch   guifg=#FFFFFF guibg=#0069CC   ctermfg=231 ctermbg=26   gui=bold
hi! link CocListLine    CursorLine
hi! link CocListSelected PmenuSel

hi CocTreeTitle       guifg=#202020 ctermfg=234 gui=bold
hi CocTreeDescription guifg=#606060 ctermfg=241
hi CocTreeOpenClose   guifg=#BBBBBB ctermfg=249
hi! link CocTreeSelected CursorLine

hi CocGitAddedSign         guifg=#587c0c guibg=#FFFFFF ctermfg=64  ctermbg=231
hi CocGitChangedSign       guifg=#667309 guibg=#FFFFFF ctermfg=58  ctermbg=231
hi CocGitRemovedSign       guifg=#ad0707 guibg=#FFFFFF ctermfg=124 ctermbg=231
hi CocGitTopRemovedSign    guifg=#ad0707 guibg=#FFFFFF ctermfg=124 ctermbg=231
hi CocGitChangeRemovedSign guifg=#667309 guibg=#FFFFFF ctermfg=58  ctermbg=231
hi CocGitBlame             guifg=#BBBBBB ctermfg=249 gui=italic cterm=italic

hi CocSnippetVisual   guibg=#EAEAEA ctermbg=254

" vim: ft=vim
