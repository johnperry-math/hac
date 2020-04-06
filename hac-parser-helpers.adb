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
    S       : KeyWSymbol;
    E       : Error_code;
    Forgive : KeyWSymbol := Dummy_Symbol
  )
  is
  begin
    if Sy = S then
      InSymbol;
    else
      Error (E);
      if Sy = Forgive then
        InSymbol;
      end if;
    end if;
  end Need;

  procedure Skip (
    FSys : Symset;
    N    : Error_code;
    hint : String := ""
  )
  is

    function StopMe return Boolean is
    begin
      return False;
    end StopMe;

  begin
    Error (N, hint);
    --
    SkipFlag := True;
    while not FSys (Sy) loop
      InSymbol;
      if StopMe then
        raise Failure_1_0;
      end if;
    end loop;

    InSymbol;    -- Manuel:  If this InSymbol call is
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
    S    : KeyWSymbol;
    N    : Error_code;
    hint : String := ""
  )
  is
  begin
    Skip (Singleton (S), N, hint);
  end Skip;

  procedure Test (
    S1, S2        : Symset;
    N             : Error_code;
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
          Error (N, stop_on_error => True, hint => To_String (hint));
        end if;
        Skip (S1 + S2, N, To_String (hint));
      end;
    end if;
  end Test;

  After_semicolon : constant Symset :=
    (IDent | TYPE_Symbol | TASK_Symbol => True, others => False) +
    Block_Begin_Symbol;

  Comma_or_colon : constant Symset :=
    Symset'(Comma | Colon => True, others => False);

  procedure Test_Semicolon (FSys : Symset) is
  begin
    if Sy = Semicolon then
      InSymbol;
      Ignore_Extra_Semicolons;
    else
      Error (err_semicolon_missing);
      if Comma_or_colon (Sy) then
        InSymbol;
      end if;
    end if;
    Test (After_semicolon, FSys, err_incorrectly_used_symbol);
  end Test_Semicolon;

  procedure Test_END_Symbol is
  begin
    if Sy = END_Symbol then
      InSymbol;
    else
      Skip (Semicolon, err_END_missing);
    end if;
  end Test_END_Symbol;

  procedure Check_Boolean (T: Types) is
  begin
    --  NB: T = NOTYP was admitted in SmallAda.
    if T /= Bools then
      Error (err_expecting_a_boolean_expression);
    end if;
  end Check_Boolean;

  procedure Ignore_Extra_Semicolons is
  begin
    if Sy = Semicolon then
      Error (err_extra_semicolon_ignored);
      while Sy = Semicolon loop
        InSymbol;
      end loop;
    end if;
  end Ignore_Extra_Semicolons;

  procedure Argument_Type_Not_Supported is
  begin
    Error (err_type_conversion_not_supported, "argument type not supported");
  end Argument_Type_Not_Supported;

  procedure Forbid_Type_Coercion (details: String) is
  begin
    Error (err_int_to_float_coercion, details, stop_on_error => True);
  end Forbid_Type_Coercion;

  function Singleton (s: KeyWSymbol) return Symset is
    res : Symset := Empty_Symset;
  begin
    res (s) := True;
    return res;
  end Singleton;

end HAC.Parser.Helpers;
