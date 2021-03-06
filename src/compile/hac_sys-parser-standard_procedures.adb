with HAC_Sys.Compiler.PCode_Emit,
     HAC_Sys.Parser.Calls,
     HAC_Sys.Parser.Expressions,
     HAC_Sys.Parser.Helpers,
     HAC_Sys.Scanner,
     HAC_Sys.UErrors;

package body HAC_Sys.Parser.Standard_Procedures is

  use Calls, Compiler.PCode_Emit, Defs, Expressions, Helpers, PCode, Scanner, UErrors;

  type Def_param_type is array (Typen, 1 .. 3) of Integer;

  invalid : constant := -1;

  def_param : constant Def_param_type :=
    (Ints    =>  (IIO.Default_Width,   IIO.Default_Base,   invalid),
     Floats  =>  (RIO.Default_Fore,    RIO.Default_Aft,    RIO.Default_Exp),
     Bools   =>  (BIO.Default_Width,   invalid,            invalid),
     others  =>  (others => invalid));

  procedure Standard_Procedure (
    CD      : in out Compiler_Data;
    Level   :        PCode.Nesting_level;
    FSys    :        Defs.Symset;
    Code    :        PCode.SP_Code
  )
  is
    procedure Check_any_String_and_promote_to_VString (X : Exact_Typ) is
    begin
      if VStrings_or_Str_Lit_Set (X.TYP) then
        if X.TYP = String_Literals then
          Emit_Std_Funct (CD, SF_Literal_to_VString);
        end if;
      else
        Type_Mismatch (
          CD, err_parameter_types_do_not_match,
          Found    => X,
          Expected => VStrings_or_Str_Lit_Set
        );
      end if;
    end Check_any_String_and_promote_to_VString;

    procedure File_I_O_Call (FIO_Code : SP_Code; Param : Operand_2_Type := 0) is
    begin
      Emit_2 (CD, k_File_I_O, SP_Code'Pos (FIO_Code), Param);
    end File_I_O_Call;
    --
    procedure Set_Abstract_Console is
    begin
      File_I_O_Call (SP_Push_Abstract_Console);
    end Set_Abstract_Console;
    --
    procedure Parse_Gets (Code : PCode.SP_Code) is
      --  Parse Get & Co including an eventual File parameter
      Found : Exact_Typ;
      with_file : Boolean;
      Code_2 : PCode.SP_Code := Code;
      String_Length_Encoding : Operand_2_Type := 0;
      use type Operand_2_Type;
    begin
      Need (CD, LParent, err_missing_an_opening_parenthesis);
      Push_by_Reference_Parameter (CD, Level, FSys, Found);
      with_file := Found.TYP = Text_Files;
      if with_file then
        Emit (CD, k_Dereference);  --  File handle's value on the stack.
        Need (CD, Comma, err_COMMA_missing);
        Push_by_Reference_Parameter (CD, Level, FSys, Found);
      end if;
      --  The "out" variable for Get, Get_Immediate, Get_Line
      --  has been pushed by reference now.
      if Found.TYP = NOTYP then
        null;  --  Error(s) already appeared in the parsing.
      elsif Text_IO_Get_Item_Set (Found.TYP) then
        if with_file then
          if Code = SP_Get_Line then
            Code_2 := SP_Get_Line_F;
          else
            Code_2 := SP_Get_F;
          end if;
        end if;
        if Found.TYP = Arrays then  --  We have a fixed-sized String here.
          if Is_Char_Array (CD, Found) then
            String_Length_Encoding := (2 ** Typen'Size) *
              Operand_2_Type (CD.Arrays_Table (Found.Ref).Array_Size);
          else
            Error (CD, err_illegal_parameters_to_Get);
          end if;
        end if;
        File_I_O_Call (Code_2, Typen'Pos (Found.TYP) + String_Length_Encoding);
      else
        Error (CD, err_illegal_parameters_to_Get);
      end if;
      Need (CD, RParent, err_closing_parenthesis_missing);
    end Parse_Gets;
    --
    procedure Parse_Puts (Code : PCode.SP_Code) is
      --  Parse Put & Co including an eventual File parameter
      Item_Typ, Format_Param_Typ : Exact_Typ;
      Format_Params : Natural := 0;
      with_file : Boolean;
      Code_2 : PCode.SP_Code := Code;
    begin
      Need (CD, LParent, err_missing_an_opening_parenthesis);
      Expression (CD, Level, FSys + Colon_Comma_RParent, Item_Typ);
      with_file := Item_Typ.TYP = Text_Files;
      if with_file then
        Need (CD, Comma, err_COMMA_missing);
        Expression (CD, Level, FSys + Colon_Comma_RParent, Item_Typ);
      end if;
      if Item_Typ.TYP = Enums then
        Item_Typ.TYP := Ints;  --  Ow... Silent S'Pos. We keep this hack until 'Image is done.
      end if;
      if Item_Typ.TYP in Standard_Typ or else Item_Typ.TYP = String_Literals then
        null;  --  Good, Put[_Line] can do it all "as is"!
      elsif Is_Char_Array (CD, Item_Typ) then
        --  Address is already pushed; we need to push the string's length.
        Emit_1 (CD, k_Push_Discrete_Literal, Operand_2_Type (CD.Arrays_Table (Item_Typ.Ref).Array_Size));
      else
        Error (CD, err_illegal_parameters_to_Put);
      end if;
      for Param in 1 .. 3 loop
        exit when CD.Sy /= Comma;
        InSymbol (CD);
        Format_Params := Format_Params + 1;
        --  Here we parse:
        --    Width, Base    for Put ([F,] I [, Width [, Base]]);
        --    Fore, Aft, Exp for Put ([F,] R [, Fore[, Aft[, Exp]]]);
        --    Width          for Put ([F,] B [, Width]);
        Expression (CD, Level, FSys + Colon_Comma_RParent, Format_Param_Typ);
        if Format_Param_Typ.TYP /= Ints then
          Error (CD, err_parameter_must_be_Integer);
        end if;
      end loop;
      --  Check given / default parameters (nice short common solution, isn't it ?)
      for Param in 1 .. Format_Params loop
        --  First we check if the programmer didn't put too many
        --  (then, undefined) parameters.
        if def_param (Item_Typ.TYP, Param) = invalid then
          Error (CD, err_illegal_parameters_to_Put);
        end if;
      end loop;
      if Item_Typ.TYP = String_Literals or else Is_Char_Array (CD, Item_Typ) then
        --  With String_Literals and String's we have *two* values pushed on the stack.
        Format_Params := Format_Params + 1;
      end if;
      for Param in Format_Params + 1 .. 3 loop
        --  Send default parameters to the stack.
        --  In order to have a fixed number of parameters in all cases,
        --  we push also the "invalid" ones. See Do_Write_Formatted
        --  to have an idea on how everybody is retrieved from the stack.
        Emit_1 (CD, k_Push_Discrete_Literal, Operand_2_Type (def_param (Item_Typ.TYP, Param)));
      end loop;
      if with_file then
        if Code = SP_Put_Line then
          Code_2 := SP_Put_Line_F;
        else
          Code_2 := SP_Put_F;
        end if;
      end if;
      File_I_O_Call (Code_2, Typen'Pos (Item_Typ.TYP));
      Need (CD, RParent, err_closing_parenthesis_missing);
    end Parse_Puts;
    --
    X : Exact_Typ;
  begin
    case Code is
      when SP_Get | SP_Get_Immediate | SP_Get_Line =>
        Parse_Gets (Code);

      when SP_Put | SP_Put_Line =>
        Parse_Puts (Code);

      when SP_New_Line | SP_Skip_Line =>
        if CD.Sy = LParent then  --  "New_Line (File);"
          InSymbol (CD);
          Expression (CD, Level, FSys + Colon_Comma_RParent, X);
          if X.TYP /= Text_Files then
            Type_Mismatch (CD, err_syntax_error, Found => X, Expected => Txt_Fil_Set);
          end if;
          Need (CD, RParent, err_closing_parenthesis_missing);
        else  --  "New_Line;"
          Set_Abstract_Console;
        end if;
        File_I_O_Call (Code);

      when SP_Wait | SP_Signal =>
        if CD.Sy /= LParent then
          Error (CD, err_missing_an_opening_parenthesis);
        else
          InSymbol (CD);
          Push_by_Reference_Parameter (CD, Level, FSys, X);
          if X.TYP = Ints then
            if Code = SP_Wait then
              Emit (CD, k_Wait_Semaphore);
            else
              Emit (CD, k_Signal_Semaphore);
            end if;
          else
            Error (CD, err_parameter_must_be_Integer);
          end if;
          Need (CD, RParent, err_closing_parenthesis_missing);
        end if;

      when SP_Open | SP_Create | SP_Append | SP_Close =>
        if CD.Sy /= LParent then
          Error (CD, err_missing_an_opening_parenthesis);
        else
          InSymbol (CD);
          Expression (CD, Level, FSys + Colon_Comma_RParent, X);
          if X.TYP /= Text_Files then
            Type_Mismatch (CD, err_syntax_error, Found => X, Expected => Txt_Fil_Set);
          end if;
          --
          --  We pass the File_Type variable as value parameter.
          --  It could be by reference, with forced initialization of
          --  the corresponding File_Ptr in the VM.
          --  But File_Ptr is always initialized anyway, to avoid
          --  text files being routed accidentally to the abstract
          --  console (= null) if Create or Open was not called.
          --
          if Code = SP_Open or Code = SP_Create or Code = SP_Append then
            --  Parse file name.
            Need (CD, Comma, err_COMMA_missing);
            Expression (CD, Level, FSys + Colon_Comma_RParent, X);
            Check_any_String_and_promote_to_VString (X);
          end if;
          File_I_O_Call (Code);
          Need (CD, RParent, err_closing_parenthesis_missing);
        end if;

      when SP_Quantum =>
        --  Cramer
        if CD.Sy /= LParent then
          Skip (CD, Semicolon, err_missing_an_opening_parenthesis);
        else
          InSymbol (CD);
          Expression (CD, Level, RParent_Set, X);
          if X.TYP /= Floats then
            Skip (CD, Semicolon, err_parameter_must_be_of_type_Float);
          end if;
          if CD.Sy /= RParent then
            Skip (CD, Semicolon, err_closing_parenthesis_missing);
          else
            Emit (CD, k_Set_Quantum_Task);
            InSymbol (CD);
          end if;
        end if;

      when SP_Priority =>
        --  Cramer
        if CD.Sy /= LParent then
          Skip (CD, Semicolon, err_missing_an_opening_parenthesis);
        else
          InSymbol (CD);
          Expression (CD, Level, RParent_Set, X);
          if X.TYP /= Ints then
            Skip (CD, Semicolon, err_parameter_must_be_Integer);
          end if;
          if CD.Sy /= RParent then
            Skip (CD, Semicolon, err_closing_parenthesis_missing);
          else
            Emit (CD, k_Set_Task_Priority);
            InSymbol (CD);
          end if;
        end if;
        --
      when SP_InheritP =>
        --  Cramer
        if CD.Sy /= LParent then
          Skip (CD, Semicolon, err_missing_an_opening_parenthesis);
        else
          InSymbol (CD);
          Boolean_Expression (CD, Level, RParent_Set, X);
          if CD.Sy /= RParent then
            Skip (CD, Semicolon, err_closing_parenthesis_missing);
          else
            Emit (CD, k_Set_Task_Priority_Inheritance);
            InSymbol (CD);
          end if;
        end if;
        --
      when SP_Set_Env | SP_Copy_File | SP_Rename =>
        Need (CD, LParent, err_missing_an_opening_parenthesis);
        for arg in 1 .. 2 loop
          Expression (CD, Level, Colon_Comma_RParent, X);  --  We push the arguments in the stack.
          --  Set_Env ( "HAC_Var",  "Hello");     <-  2 String_Literals
          --  Set_Env (+"HAC_Var", +"Hello");     <-  2 VStrings
          --  Set_Env (+"HAC_Var",  "Hello");
          --  Set_Env ( "HAC_Var", +"Hello");
          Check_any_String_and_promote_to_VString (X);
          if arg < 2 then
            Need (CD, Comma, err_COMMA_missing);
          end if;
        end loop;
        File_I_O_Call (Code);
        Need (CD, RParent, err_closing_parenthesis_missing);

      when SP_Delete_File | SP_Set_Directory =>
        Need (CD, LParent, err_missing_an_opening_parenthesis);
        Expression (CD, Level, RParent_Set, X);  --  We push the argument in the stack.
        Check_any_String_and_promote_to_VString (X);
        File_I_O_Call (Code);
        Need (CD, RParent, err_closing_parenthesis_missing);

      when SP_Shell_Execute =>
        Need (CD, LParent, err_missing_an_opening_parenthesis);
        Expression (CD, Level, Comma_RParent, X);  --  We push the argument in the stack.
        Check_any_String_and_promote_to_VString (X);
        if CD.Sy = Comma then
          InSymbol (CD);
          Push_by_Reference_Parameter (CD, Level, RParent_Set, X);
          if X.TYP /= Ints then
            Skip (CD, Semicolon, err_parameter_must_be_Integer);
          end if;
          File_I_O_Call (SP_Shell_Execute_with_Result);       --  Shell_Execute (cmd, result);
        else
          File_I_O_Call (SP_Shell_Execute_without_Result);    --  Shell_Execute (cmd);
        end if;
        Need (CD, RParent, err_closing_parenthesis_missing);

      when SP_Set_Exit_Status =>
        Need (CD, LParent, err_missing_an_opening_parenthesis);
        Expression (CD, Level, Comma_RParent, X);  --  We push the argument in the stack.
        if X.TYP /= Ints then
          Skip (CD, Semicolon, err_parameter_must_be_Integer);
        end if;
        File_I_O_Call (SP_Set_Exit_Status);
        Need (CD, RParent, err_closing_parenthesis_missing);

      when SP_Push_Abstract_Console =>
        null;  --  Internal: used by Get, Put, etc. without file parameter.
      when SP_Get_F | SP_Get_Line_F |
           SP_Put_F | SP_Put_Line_F =>
        null;  --  "Fronted" by SP_Get, SP_Get_Line,... Used by VM.
    end case;
  end Standard_Procedure;

end HAC_Sys.Parser.Standard_Procedures;
