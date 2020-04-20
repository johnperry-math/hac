-------------------------------------------------------------------------------------
--
--  HAC - HAC Ada Compiler
--
--  A compiler in Ada for an Ada subset
--
--  Copyright, license, etc. : see top package.
--
-------------------------------------------------------------------------------------
--

with HAC.Scanner;

with Ada.Strings.Unbounded;

package body HAC.Parser.Helpers is

  use HAC.Scanner, Ada.Strings.Unbounded;

  procedure Need (
    CD      : in out Compiler_Data;
    S       : KeyWSymbol;
    E       : Compile_Error;
    Forgive : KeyWSymbol := Dummy_Symbol
  )
  is
  begin
    if Sy = S then
      InSymbol (CD);
    else
      Error (CD, E);
      if Sy = Forgive then
        InSymbol (CD);
      end if;
    end if;
  end Need;

  procedure Skip (
    CD   : in out Compiler_Data;
    FSys : Symset;
    N    : Compile_Error;
    hint : String := ""
  )
  is

    function StopMe return Boolean is
    begin
      return False;
    end StopMe;

  begin
    Error (CD, N, hint);
    --
    SkipFlag := True;
    while not FSys (Sy) loop
      InSymbol (CD);
      if StopMe then
        raise Failure_1_0;
      end if;
    end loop;

    InSymbol (CD);    -- Manuel:  If this InSymbol call is
    -- omitted, the system will get in an
    -- infinite loop on the statement:
    --  put_lin("Typo is on purpose");

    if StopMe then
      raise Failure_1_0;
    end if;
    if SkipFlag then
      EndSkip;
    end if;
  end Skip;

  procedure Skip (
    CD   : in out Compiler_Data;
    S    : KeyWSymbol;
    N    : Compile_Error;
    hint : String := ""
  )
  is
  begin
    Skip (CD, Singleton (S), N, hint);
  end Skip;

  procedure Test (
    CD            : in out Compiler_Data;
    S1, S2        : Symset;
    N             : Compile_Error;
    stop_on_error : Boolean:= False)
  is
  begin
    if not S1 (Sy) then
      declare
        hint  : Unbounded_String;
        first : Boolean := True;
      begin
        for s in S1'Range loop
          if S1 (s) then
            if not first then
              hint := hint & ", ";
            end if;
            first := False;
            hint := hint & KeyWSymbol'Image (s);
          end if;
        end loop;
        hint := "Found: " & KeyWSymbol'Image (Sy) & "; expected: " & hint;
        if stop_on_error then
          Error (CD, N, stop_on_error => True, hint => To_String (hint));
        end if;
        Skip (CD, S1 + S2, N, To_String (hint));
      end;
    end if;
  end Test;

  After_semicolon : constant Symset :=
    (IDent | TYPE_Symbol | TASK_Symbol => True, others => False) +
    Block_Begin_Symbol;

  Comma_or_colon : constant Symset :=
    Symset'(Comma | Colon => True, others => False);

  procedure Test_Semicolon (CD : in out Compiler_Data; FSys : Symset) is
  begin
    if Sy = Semicolon then
      InSymbol (CD);
      Ignore_Extra_Semicolons (CD);
    else
      Error (CD, err_semicolon_missing);
      if Comma_or_colon (Sy) then
        InSymbol (CD);
      end if;
    end if;
    Test (CD, After_semicolon, FSys, err_incorrectly_used_symbol);
  end Test_Semicolon;

  procedure Test_END_Symbol (CD : in out Compiler_Data) is
  begin
    if Sy = END_Symbol then
      InSymbol (CD);
    else
      Skip (CD, Semicolon, err_END_missing);
    end if;
  end Test_END_Symbol;

  procedure Check_Boolean (CD : Compiler_Data; T: Types) is
  begin
    --  NB: T = NOTYP was admitted in SmallAda.
    if T /= Bools then
      Error (CD, err_expecting_a_boolean_expression);
    end if;
  end Check_Boolean;

  procedure Ignore_Extra_Semicolons (CD : in out Compiler_Data) is
  begin
    if Sy = Semicolon then
      Error (CD, err_extra_semicolon_ignored);
      while Sy = Semicolon loop
        InSymbol (CD);
      end loop;
    end if;
  end Ignore_Extra_Semicolons;

  procedure Argument_Type_Not_Supported (CD : Compiler_Data) is
  begin
    Error (CD, err_type_conversion_not_supported, "argument type not supported");
  end Argument_Type_Not_Supported;

  procedure Forbid_Type_Coercion (CD : Compiler_Data; details: String) is
  begin
    Error (CD, err_int_to_float_coercion, details, stop_on_error => True);
  end Forbid_Type_Coercion;

  function Singleton (s: KeyWSymbol) return Symset is
    res : Symset := Empty_Symset;
  begin
    res (s) := True;
    return res;
  end Singleton;

end HAC.Parser.Helpers;
