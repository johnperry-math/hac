with HAC.Data;    use HAC.Data;
with HAC.UErrors; use HAC.UErrors;

with Ada.Text_IO; use Ada.Text_IO;

package body HAC.Scanner is

  package IIO is new Integer_IO (Integer);
  use IIO;

  type SSTBzz is array (Character'(' ') .. ']') of KeyWSymbol;

  Special_Symbols : constant SSTBzz :=
   ('+'    => Plus,
    '-'    => Minus,
    '*'    => Times,
    '/'    => Divide,
    '('    => LParent,
    ')'    => RParent,
    '['    => LBrack,
    ']'    => RBrack,
    '='    => EQL,
    '"'    => NEQ,    -- ?!
    ','    => Comma,
    ';'    => Semicolon,
    '&'    => Ampersand_Symbol,
    others => NULL_Symbol);

  type CHTP is (Letter, LowCase, Number, Special, Illegal);

  type Set_of_CHTP is array (CHTP) of Boolean;

  special_or_illegal : constant Set_of_CHTP :=
   (Letter   |
    LowCase  |
    Number   => False,
    Special  |
    Illegal  => True);

  c128 : constant Character := Character'Val (128);

  CharacterTypes : constant array (Character) of CHTP :=
    (   'A' .. 'Z' => Letter,
        'a' .. 'z' => LowCase,
        '0' .. '9' =>  Number,
        '+' | '-' | '*' | '/' |
        '(' | ')' |
        '$' |
        '=' |
        ' ' |
        ',' |
        '.' |
        ''' |
        '[' |
        ']' |
        ':' |
        '^' |
        '_' |
        ';' |
        '{' |
        '|' |
        '}' |
        '<' |
        '>' |
        '"' => Special,
        c128 => Special,
        others => Illegal);

  subtype AdaKeyW_String is String (1 .. 12);

  type AdaKeyW_Pair is record
    st : AdaKeyW_String;
    sy : KeyWSymbol;
  end record;

  type AdaKeyW_List is array(Positive range <>) of AdaKeyW_Pair;

  AdaKeyW : constant AdaKeyW_List:=
      ( ("ABORT       ", ABORT_Symbol),
        ("ABSTRACT    ", ABSTRACT_Symbol),     -- [added in] Ada 95
        ("ABS         ",  USy),                -- !! SmallAda has a built-in function (wrong)
        ("ACCEPT      ", ACCEPT_Symbol),
        ("ACCESS      ", ACCESS_Symbol),
        ("ALIASED     ", ALIASED_Symbol),      -- Ada 95
        ("ALL         ", ALL_Symbol),          -- Ada 95
        ("AND         ", AND_Symbol),
        ("ARRAY       ", ARRAY_Symbol),
        ("AT          ", AT_Symbol),
        ("BEGIN       ", BEGIN_Symbol),
        ("BODY        ", BODY_Symbol),
        ("CASE        ", CASE_Symbol),
        ("CONSTANT    ", CONSTANT_Symbol),
        ("DECLARE     ", DECLARE_Symbol),
        ("DELAY       ", DELAY_Symbol),
        ("DELTA       ", DELTA_Symbol),
        ("DIGITS      ", DIGITS_Symbol),
        ("DO          ", DO_Symbol),
        ("ELSE        ", ELSE_Symbol),
        ("ELSIF       ", ELSIF_Symbol),
        ("END         ", END_Symbol),
        ("ENTRY       ", ENTRY_Symbol),
        ("EXCEPTION   ", EXCEPTION_Symbol),
        ("EXIT        ", EXIT_Symbol),
        ("FOR         ", FOR_Symbol),
        ("FUNCTION    ", FUNCTION_Symbol),
        ("GENERIC     ", GENERIC_Symbol),
        ("GOTO        ", GOTO_Symbol),
        ("IF          ", IF_Symbol),
        ("IN          ", IN_Symbol),
        ("INTERFACE   ", INTERFACE_Symbol),    -- Ada 2005
        ("IS          ", IS_Symbol),
        ("LIMITED     ", LIMITED_Symbol),
        ("LOOP        ", LOOP_Symbol),
        ("MOD         ", MOD_Symbol),
        ("NEW         ", NEW_Symbol),
        ("NOT         ", NOT_Symbol),
        ("NULL        ", NULL_Symbol),
        ("OF          ", OF_Symbol),
        ("OR          ", OR_Symbol),
        ("OTHERS      ", OTHERS_Symbol),
        ("OUT         ", OUT_Symbol),
        ("OVERRIDING  ", OVERRIDING_Symbol),   -- Ada 2005
        ("PACKAGE     ", PACKAGE_Symbol),
        ("PRAGMA      ", PRAGMA_Symbol),
        ("PRIVATE     ", PRIVATE_Symbol),
        ("PROCEDURE   ", PROCEDURE_Symbol),
        ("PROTECTED   ", PROTECTED_Symbol),    -- Ada 95
        ("RAISE       ", RAISE_Symbol),
        ("RANGE       ", RANGE_Keyword_Symbol),
        ("RECORD      ", RECORD_Symbol),
        ("REM         ", REM_Symbol),
        ("RENAMES     ", RENAMES_Symbol),
        ("REQUEUE     ", REQUEUE_Symbol),      -- Ada 95
        ("RETURN      ", RETURN_Symbol),
        ("REVERSE     ", REVERSE_Symbol),
        ("SELECT      ", SELECT_Symbol),
        ("SEPARATE    ", SEPARATE_Symbol),
        ("SOME        ", SOME_Symbol),         -- Ada 2012
        ("SUBTYPE     ", SUBTYPE_Symbol),
        ("SYNCHRONIZED", SYNCHRONIZED_Symbol), -- Ada 2005
        ("TAGGED      ", TAGGED_Symbol),       -- Ada 95
        ("TASK        ", TASK_Symbol),
        ("TERMINATE   ", TERMINATE_Symbol),
        ("THEN        ", THEN_Symbol),
        ("TYPE        ", TYPE_Symbol),
        ("UNTIL       ", UNTIL_Symbol),        -- Ada 95
        ("USE         ", USE_Symbol),
        ("WHEN        ", WHEN_Symbol),
        ("WHILE       ", WHILE_Symbol),
        ("WITH        ", WITH_Symbol),
        ("XOR         ", XOR_Symbol)
       );

  procedure InSymbol (CD : in out Compiler_Data) is
    I, J, K, e : Integer;
    theLine    : Source_Line_String;

    function UpCase (c : Character) return Character is
    begin
      if c in 'a' .. 'z' then
        return Character'Val
                (Character'Pos (c) -
                 Character'Pos ('a') +
                 Character'Pos ('A'));
      else
        return c;
      end if;
    end UpCase;

    procedure NextCh is  --  Read Next Char; process line end
    begin
      if CD.CC = CD.LL then
        if Listing_Was_Requested then
          New_Line (Listing);
        end if;
        CD.Line_Count := CD.Line_Count + 1;
        if Listing_Was_Requested then
          Put (Listing, CD.Line_Count, 4);
          Put (Listing, "  ");
          --  Put (Listing, LC, 5);
          --  Put (Listing, "  ");
        end if;
        CD.LL := 0;
        CD.CC := 0;
        c_Get_Next_Line (theLine, CD.LL);
        CD.InpLine (1 .. CD.LL + 1) := theLine (1 .. CD.LL) & ' ';
        CD.LL := CD.LL + 1;

        if Listing_Was_Requested then
          New_Line (Listing);
          Put_Line (Listing, CD.InpLine);
        end if;
      end if;

      CD.CC := CD.CC + 1;
      CD.CH := CD.InpLine (CD.CC);
      -- Manuel : Change tabs for spaces
      if Character'Pos (CD.CH) = 9 then
        CD.CH := ' '; -- IdTab for space
      end if;
      if Character'Pos (CD.CH) < Character'Pos (' ') then
        Error (CD, err_control_character);
      end if;

    end NextCh;

    procedure Read_Scale (allow_minus : Boolean) is
      S, Sign : Integer;
    begin
      NextCh;
      Sign := 1;
      S    := 0;
      if CD.CH = '+' then
        NextCh;
      elsif CD.CH = '-' then
        if allow_minus then
          NextCh;
          Sign := -1;
        else
          Error (
            CD, err_negative_exponent_for_integer_literal,
            Integer'Image(CD.INum) & ".0e- ..."
          );
        end if;
      end if;
      if CD.CH not in '0' .. '9' then
        Error (CD, err_illegal_character_in_number, "; expected digit after 'E'");
      else
        loop
          S := 10 * S + Character'Pos (CD.CH) - Character'Pos ('0');
          NextCh;
          exit when CD.CH not in '0' .. '9';
        end loop;
      end if;
      e := S * Sign + e;
    end Read_Scale;

    procedure Adjust_Scale is
      S    : Integer;
      D, T : HAC_Float;
    begin
      if K + e > EMax then
        Error (
          CD, err_number_too_large,
          Integer'Image (K) & " +" &
          Integer'Image (e) & " =" &
          Integer'Image (K + e) & " > Max =" &
          Integer'Image (EMax)
        );
      elsif K + e < EMin then
        CD.RNum := 0.0;
      else
        S := abs e;
        T := 1.0;
        D := 10.0;
        loop
          while S rem 2 = 0 loop
            S := S / 2;
            D := D ** 2;
          end loop;
          S := S - 1;
          T := D * T;
          exit when S = 0;
        end loop;
        if e >= 0 then
          CD.RNum := CD.RNum * T;
        else
          CD.RNum := CD.RNum / T;
        end if;
      end if;
    end Adjust_Scale;

    procedure Scan_Number is
      procedure Skip_eventual_underscore is
      begin
        if CD.CH = '_' then
          NextCh;
          if CD.CH = '_' then
            Error (CD, err_double_underline_not_permitted, stop_on_error => True);
          elsif CharacterTypes (CD.CH) /= Number then
            Error (CD, err_digit_expected, stop_on_error => True);
          end if;
        end if;
      end Skip_eventual_underscore;
    begin
      K       := 0;
      CD.INum := 0;
      CD.Sy   := IntCon;
      --  Scan the integer part of the number.
      loop
        CD.INum := CD.INum * 10 + Character'Pos (CD.CH) - Character'Pos ('0');
        K    := K + 1;
        NextCh;
        Skip_eventual_underscore;
        exit when CharacterTypes (CD.CH) /= Number;
      end loop;
      --
      if K > KMax then
        Error (
          CD, err_number_too_large,
          Integer'Image (K) & " > Max =" &
          Integer'Image (KMax)
        );
        CD.INum := 0;
        K       := 0;
      end if;
      if CD.CH = '.' then
        NextCh;
        if CD.CH = '.' then  --  Double dot.
          CD.CH := c128;
        else
          --  Read decimal part.
          CD.Sy := FloatCon;
          CD.RNum  := HAC_Float (CD.INum);
          e     := 0;
          while CharacterTypes (CD.CH) = Number loop
            e    := e - 1;
            CD.RNum := 10.0 * CD.RNum +
                    HAC_Float (Character'Pos (CD.CH) - Character'Pos ('0'));
            NextCh;
            Skip_eventual_underscore;
          end loop;
          if e = 0 then
            Error (CD, err_illegal_character_in_number, "; expected digit after '.'");
          end if;
          if CD.CH = 'E' or CD.CH = 'e' then
            Read_Scale (True);
          end if;
          if e /= 0 then
            Adjust_Scale;
          end if;
        end if;
      elsif CD.CH = 'E' or CD.CH = 'e' then
        --  Integer with exponent: 123e4.
        e := 0;
        Read_Scale (False);
        if e /= 0 then
          CD.INum := CD.INum * 10 ** e;
        end if;
      end if;
    end Scan_Number;

    exit_big_loop : Boolean;

  begin  --  InSymbol

    Big_loop:
    loop
      Small_loop:
      loop
        while CD.CH = ' ' loop
          NextCh;
        end loop;

        CD.syStart := CD.CC - 1;
        if CharacterTypes (CD.CH) = Illegal then
          Error (CD, err_illegal_character);
          if qDebug then
            Put_Line (" Char is => " & Integer'Image (Character'Pos (CD.CH)));
          end if;
          if Listing_Was_Requested then
            Put_Line
             (Listing,
              " Char is => " & Integer'Image (Character'Pos (CD.CH)));
          end if;
          NextCh;
        else
          exit Small_loop;
        end if;
      end loop Small_loop;

      exit_big_loop := True;
      case CD.CH is
        when 'A' .. 'Z' |  --  identifier or wordsymbol
             'a' .. 'z' =>
          K  := 0;
          CD.Id := Empty_Alfa;
          CD.Id_with_case := CD.Id;
          loop
            if K < Alng then
              K := K + 1;
              CD.Id (K)           := UpCase (CD.CH);
              CD.Id_with_case (K) := CD.CH;
              if K > 1 and then CD.Id (K - 1 .. K) = "__" then
                Error (CD, err_double_underline_not_permitted, CD.Id, stop_on_error => True);
              end if;
            else
              Error (CD, err_identifier_too_long, CD.Id);
            end if;
            NextCh;
            exit when CD.CH /= '_'
                     and then special_or_illegal (CharacterTypes (CD.CH));
          end loop;
          if K > 0 and then CD.Id (K) ='_' then
            Error (CD, err_identifier_cannot_end_with_underline, CD.Id, stop_on_error => True);
          end if;
          --
          I := 1;
          J := AdaKeyW'Last;  --  Binary Search
          loop
            K := (I + J) / 2;
            if CD.Id (AdaKeyW_String'Range) <= AdaKeyW (K).st then
              J := K - 1;
            end if;
            if CD.Id (AdaKeyW_String'Range) >= AdaKeyW (K).st then
              I := K + 1;
            end if;
            exit when I > J;
          end loop;
          --
          if I - 1 > J then
            CD.Sy := AdaKeyW (K).sy;
          else
            CD.Sy := IDent;
          end if;
          if CD.Sy = USy then
            CD.Sy := IDent;
            Error (CD, err_Ada_reserved_word);
          end if;

        when '0' .. '9' =>
          Scan_Number;

        when ':' =>
          NextCh;
          if CD.CH = '=' then
            CD.Sy := Becomes;
            NextCh;
          else
            CD.Sy := Colon;
          end if;

        when '<' =>
          NextCh;
          if CD.CH = '=' then
            CD.Sy := LEQ;
            NextCh;
          else
            CD.Sy := LSS;
          end if;

        when '>' =>
          NextCh;
          if CD.CH = '=' then
            CD.Sy := GEQ;
            NextCh;
          else
            CD.Sy := GTR;
          end if;

        when '/' =>
          NextCh;
          if CD.CH = '=' then
            CD.Sy := NEQ;
            NextCh;
          else
            CD.Sy := Divide;
          end if;

        when '.' =>
          NextCh;
          if CD.CH = '.' then
            CD.Sy := Range_Double_Dot_Symbol;
            NextCh;
          else
            CD.Sy := Period;
          end if;

        when c128 =>  --  Hathorn
          CD.Sy := Range_Double_Dot_Symbol;
          NextCh;

        when '"' =>
          K := 0;
          loop
            NextCh;
            if CD.CH = '"' then
              NextCh;
              if CD.CH /= '"' then  --  The ""x case
                exit;
              end if;
            end if;
            if CD.Strings_Table_Top + K = SMax then
              Fatal (STRING_CONSTANTS);
            end if;
            CD.Strings_Table (CD.Strings_Table_Top + K) := CD.CH;
            K := K + 1;
            if CD.CC = 1 then
              K := 0;  --  END OF InpLine
              exit;
            else
              null;  --  Continue
            end if;
          end loop;
          CD.Sy    := StrCon;
          CD.INum  := CD.Strings_Table_Top;
          CD.SLeng := K;
          CD.Strings_Table_Top := CD.Strings_Table_Top + K;
          --  TBD: we could compress this information by searching already existing strings
          --       in the table! (Quick search as for Lempel-Ziv string matchers - cf LZ77
          --       package in the Zip-Ada project.

        when ''' =>
          --  Character literal (code reused from Pascal string literal, hence a loop)
          --  !! We will need to reprogram that for attributes or qualified expressions.
          K := 0;
          loop
            NextCh;
            if CD.CH = ''' then
              NextCh;
              if CD.CH /= ''' then  --  The ''x case
                exit;
              end if;
            end if;
            if CD.Strings_Table_Top + K = SMax then
              Fatal (STRING_CONSTANTS);
            end if;
            CD.Strings_Table (CD.Strings_Table_Top + K) := CD.CH;
            K := K + 1;
            if CD.CH = ''' and K = 1 then  --  The ''' case
              NextCh;
              exit;
            end if;
            if CD.CC = 1 then
              K := 0;  --  END OF InpLine
              exit;
            else
              null;  --  Continue
            end if;
          end loop;
          --
          if K = 1 then  --  Correct, we have a "string" of length 1.
            CD.Sy := CharCon;
            CD.INum  := Character'Pos (CD.Strings_Table (CD.Strings_Table_Top));
            --  CD.Strings_Table_Top is NOT incremented.
          elsif K = 0 then
            Error (CD, err_character_zero_chars);
            CD.Sy := CharCon;
            CD.INum  := 0;
          else
            Error (CD, err_character_delimeter_used_for_string);
            CD.Sy    := StrCon;
            CD.INum  := CD.Strings_Table_Top;
            CD.SLeng := K;
            CD.Strings_Table_Top := CD.Strings_Table_Top + K;
          end if;

        when '-' =>
          NextCh;
          if CD.CH /= '-' then
            CD.Sy := Minus;
          else  --  comment
            CD.CC := CD.LL;  --  ignore rest of input line
            NextCh;
            exit_big_loop := False;
          end if;

        when '=' =>
          NextCh;
          if CD.CH /= '>' then
            CD.Sy := EQL;
          else
            CD.Sy := Finger;
            NextCh;
          end if;

        when '{' =>  --  Special non documented comment !! O_o: remove that !!
          while CD.CH /= '}' loop
            NextCh;
          end loop;
          NextCh;
          exit_big_loop := False;

        when '|' =>
          CD.Sy := Alt;
          NextCh;

        when '+' | '*' | '(' | ')' | ',' | '[' | ']' | ';' | '&' =>
          CD.Sy := Special_Symbols (CD.CH);
          NextCh;
          if CD.Sy = Times and then CD.CH = '*' then  --  Get the "**" operator symbol
            CD.Sy := Power;
            NextCh;
          end if;

        when '$' | '!' | '@' | '\' | '^' | '_' | '?' | '%' =>
          --  duplicate case Constant '&',
          Error (CD, err_illegal_character);
          if qDebug then
            Put_Line (" [ $!@\^_?""&%  ]");
          end if;
          if Listing_Was_Requested then
            Put_Line (Listing, " [ $!@\^_?""&%  ]");
          end if;
          NextCh;
          exit_big_loop := False;

        when Character'Val (0) .. ' ' =>
          null;
        when others =>
          null;

      end case;  --  CD.CH
      exit Big_loop when exit_big_loop;
    end loop Big_loop;

    CD.syEnd := CD.CC - 1;

    if qDebug then
      Put_Line(Sym_dump, CD.InpLine (1 .. CD.LL));
      for i in 1 .. CD.CC-2 loop
        Put(Sym_dump,'.');
      end loop;
      Put_Line(Sym_dump,"^");
      Put (Sym_dump,
        '[' & Integer'Image(CD.Line_Count) & ':' &
              Integer'Image(CD.CC) & ":] " &
        KeyWSymbol'Image (CD.Sy)
      );
      case CD.Sy is
        when IDent =>
          Put (Sym_dump, ": " & CD.Id);
        when IntCon =>
          Put (Sym_dump, ": " & Integer'Image (CD.INum));
        when FloatCon =>
          Put (Sym_dump, ": " & HAC_Float'Image (CD.RNum));
        when StrCon =>
          Put (Sym_dump, ": """);
          for i in CD.INum .. CD.INum + CD.SLeng - 1 loop
            Put (Sym_dump, CD.Strings_Table (i));
          end loop;
          Put (Sym_dump, '"');
        when Becomes =>
          Put (Sym_dump, " := ");
        when Colon =>
          Put (Sym_dump, " : ");
        when CONSTANT_Symbol =>
          Put (Sym_dump, " constant ");
        when others =>
          null;
      end case;
      New_Line(Sym_dump, 2);
    end if;

  end InSymbol;

end HAC.Scanner;
