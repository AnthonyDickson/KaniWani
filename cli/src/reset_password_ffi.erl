-module(reset_password_ffi).
-export([get_password/0]).

get_password() ->
    % Switch the terminal to raw mode so we receive individual keypresses
    % rather than waiting for a full line. This also suppresses echo.
    ok = shell:start_interactive({noshell, raw}),
    try read_password([]) of
        eof           -> {error, eof};
        {error, Desc} -> {error, Desc};
        Chars         -> {ok, Chars}
    after
        % Always restore cooked mode and print a newline (since the user's
        % Enter keypress was not echoed in raw mode).
        shell:start_interactive({noshell, cooked}),
        io:put_chars("\n")
    end.

read_password(Acc) ->
    % In raw mode, io:get_chars returns individual bytes as binaries (e.g. <<102>>)
    % rather than the strings or charlists you would get in cooked mode.
    case io:get_chars("", 1) of
        % Ctrl+D sends byte 0x04, which is EOF in cooked mode but is just a
        % regular byte in raw mode, so we handle it explicitly.
        <<4>>    -> eof;
        <<$\n>>  -> lists:reverse(Acc);
        % Terminals typically send CR (0x0D) rather than LF (0x0A) for Enter
        % in raw mode.
        <<$\r>>  -> lists:reverse(Acc);
        eof      -> eof;
        {error, Desc} -> {error, Desc};
        % Backspace sends DEL (0x7F) rather than BS (0x08) on most modern
        % terminals.
        <<127>>  -> read_password(drop(Acc));
        % ESC (0x1B) is the start of an escape sequence (e.g. arrow keys,
        % Delete). We discard the whole sequence since we have no cursor to
        % move.
        <<27>>   -> read_escape(Acc);
        <<Char>> -> read_password([Char | Acc])
    end.

% The accumulator is built in reverse (newest chars at the head) so dropping
% the head removes the most recently typed character.
drop([])         -> [];
drop([_ | Rest]) -> Rest.

read_escape(Acc) ->
    case io:get_chars("", 1) of
        % CSI (Control Sequence Introducer) is ESC followed by [. Most
        % keyboard escape sequences use this form.
        <<$[>> -> read_csi(Acc);
        % SS3 sequences (ESC O ...) used by F1-F4 and some terminals for
        % arrow keys. They are always exactly one byte after the O, so
        % consume that byte and discard the whole sequence.
        <<$O>> -> io:get_chars("", 1), read_password(Acc);
        % Any other ESC sequence — discard and resume.
        _      -> read_password(Acc)
    end.

% CSI sequences end with a "final byte" in the range 0x40-0x7E (e.g. ~, A, B).
% Parameter and intermediate bytes (e.g. digits, semicolons) come before it.
% We consume everything and discard it.
read_csi(Acc) ->
    case io:get_chars("", 1) of
        <<Byte>> when Byte >= 16#40, Byte =< 16#7E -> read_password(Acc);
        eof           -> eof;
        {error, Desc} -> {error, Desc};
        _             -> read_csi(Acc)
    end.
