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
--  This package defines the PCode Virtual Machine.

with HAC_Sys.Defs;

with Ada.Text_IO;  --  Only used for file descriptors

package HAC_Sys.PCode is

  -----------------------------------------------------PCode Opcodes----

  type Opcode is
  (
    k_Push_Address,
    k_Push_Value,
    k_Push_Indirect_Value,
    k_Push_Discrete_Literal,
    k_Push_Float_Literal,
    --
    k_Variable_Initialization,
    k_Update_Display_Vector,
    k_Store,
    --
    k_Standard_Functions,
    --
    k_Jump,
    k_Conditional_Jump,
    --
    k_CASE_Switch,
    k_CASE_Choice_Data,
    k_CASE_Match_Jump,
    k_CASE_No_Choice_Found,
    --
    k_FOR_Forward_Begin,
    k_FOR_Forward_End,
    k_FOR_Reverse_Begin,
    k_FOR_Reverse_End,
    k_FOR_Release_Stack_After_End,
    --
    k_Array_Index_Element_Size_1,
    k_Array_Index,
    k_Record_Field_Offset,
    k_Load_Block,
    k_Copy_Block,
    k_String_Literal_Assignment,
    --
    k_Mark_Stack,                       --  First instruction for a Call
    k_Call,                             --  Procedure and task entry Call
    k_Exit_Call,
    k_Exit_Function,
    --
    k_Integer_to_Float,                 --  The reverse conversion is done by a k_Standard_Functions
    k_Dereference,
    k_Unary_MINUS_Float,                --  2020-04-04
    k_Unary_MINUS_Integer,
    k_NOT_Boolean,
    --
    k_EQL_Integer,
    k_NEQ_Integer,
    k_LSS_Integer,
    k_LEQ_Integer,
    k_GTR_Integer,
    k_GEQ_Integer,
    --
    k_EQL_VString,
    k_NEQ_VString,
    k_LSS_VString,
    k_LEQ_VString,
    k_GTR_VString,
    k_GEQ_VString,
    --
    k_EQL_Float,
    k_NEQ_Float,
    k_LSS_Float,
    k_LEQ_Float,
    k_GTR_Float,
    k_GEQ_Float,
    --
    k_ADD_Integer,
    k_SUBTRACT_Integer,
    k_MULT_Integer,
    k_DIV_Integer,
    k_MOD_Integer,
    k_Power_Integer,                    --  2018-03-18 : 3 ** 6
    --
    k_ADD_Float,
    k_SUBTRACT_Float,
    k_MULT_Float,
    k_DIV_Float,
    k_Power_Float,                      --  2018-03-22 : 3.14 ** 6.28
    k_Power_Float_Integer,              --  2018-03-22 : 3.14 ** 6
    --
    k_OR_Boolean,
    k_AND_Boolean,
    k_XOR_Boolean,
    --
    k_File_I_O,
    --
    k_Halt_Interpreter,                 --  Switch off the processor's running loop
    k_Accept_Rendezvous,
    k_End_Rendezvous,
    k_Wait_Semaphore,
    k_Signal_Semaphore,
    k_Delay,
    k_Set_Quantum_Task,
    k_Set_Task_Priority,
    k_Set_Task_Priority_Inheritance,
    k_Selective_Wait
  );

  subtype Unary_Operator_Opcode  is Opcode range k_Integer_to_Float .. k_NOT_Boolean;
  subtype Binary_Operator_Opcode is Opcode range k_EQL_Integer .. k_XOR_Boolean;
  --
  subtype Atomic_Data_Push_Opcode is Opcode range k_Push_Address .. k_Push_Float_Literal;
  subtype Calling_Opcode          is Opcode range k_Mark_Stack .. k_Exit_Function;
  subtype CASE_Data_Opcode        is Opcode range k_CASE_Choice_Data .. k_CASE_No_Choice_Found;
  subtype Composite_Data_Opcode   is Opcode range k_Array_Index_Element_Size_1 .. k_String_Literal_Assignment;
  subtype Jump_Opcode             is Opcode range k_Jump .. k_Conditional_Jump;
  subtype Multi_Statement_Opcode  is Opcode range k_CASE_Switch .. k_FOR_Release_Stack_After_End;
  subtype Tasking_Opcode          is Opcode range k_Halt_Interpreter .. k_Selective_Wait;

  function For_END (for_BEGIN : Opcode) return Opcode;

  type Opcode_Set is array (Opcode) of Boolean;
  OK_for_Exception : constant Opcode_Set :=
    (k_Exit_Call .. k_Exit_Function | k_Halt_Interpreter => True, others => False);

  type Operand_1_Type is new Integer;  --  Mostly used to pass nesting levels
  subtype Nesting_level is Operand_1_Type range 0 .. HAC_Sys.Defs.Nesting_Level_Max;

  --  Type for operand 2 (Y) is large enough for containing
  --  addresses, plus signed integer values *in* HAC programs.
  --
  subtype Operand_2_Type is HAC_Sys.Defs.HAC_Integer;

  type Debug_Info is record
    --  Line number in the source code.
    Line_Number   : Positive;
    --  Current block's path (if any). Example: hac-pcode-interpreter.adb.
    Full_Block_Id : Defs.VString;
    --  Source code file name.         Example: HAC.PCode.Interpreter.Do_Write_Formatted.
    File_Name     : Defs.VString;
  end record;

  --  PCode instruction record (stores a compiled PCode instruction)
  type Order is record
    F : Opcode;          --  Opcode (or instruction field)
    X : Operand_1_Type;  --  Operand 1 is mostly used to point to the static level
    Y : Operand_2_Type;  --  Operand 2 is used to pass addresses and sizes to the
                         --    instructions or immediate discrete values (k_Literal).
    D : Debug_Info;
  end record;

  type Object_Code_Table is array (Natural range <>) of Order;

  --  For jumps forward in the code towards an ELSE, ELSIF, END IF, END LOOP, ...
  --  When the code is emited, the address is still unknown.
  --  When the address is known, jump addresses are patched.

  --  Patching using dummy addresses.
  --  For loops, this technique can be used only for exiting
  --  the current loop.

  dummy_address_if   : constant := -1;
  dummy_address_loop : constant := -2;

  --  Patch to OC'Last all addresses of Jump_Opcode's which are equal to dummy_address.
  procedure Patch_Addresses (
    OC            : in out Object_Code_Table;
    dummy_address :        Operand_2_Type
  );

  --  Mechanism for patching instructions at selected addresses.
  type Patch_Table is array (Positive range <>) of Operand_2_Type;
  subtype Fixed_Size_Patch_Table is Patch_Table (1 .. HAC_Sys.Defs.Patch_Max);

  --  Patch to OC'Last all addresses for Jump instructions whose
  --  addresses are contained in the Patch_Table, up to index Top.
  --  Reset Top to 0.
  procedure Patch_Addresses (
    OC  : in out Object_Code_Table;
    PT  :        Patch_Table;
    Top : in out Natural
  );

  --  Add new instruction address to a Patch_Table.
  procedure Feed_Patch_Table (
    PT  : in out Patch_Table;
    Top : in out Natural;
    LC  :        Integer
  );

  procedure Dump (
    OC        : Object_Code_Table;
    Str_Const : String;
    Flt_Const : Defs.Float_Constants_Table_Type;
    Text      : Ada.Text_IO.File_Type
  );

  --  Store PCode instruction in the object code table OC at position LC and increments LC.

  procedure Emit_Instruction (
    OC   : in out Object_Code_Table;
    LC   : in out Integer;
    D    :        Debug_Info;
    FCT  :        Opcode;
    a    :        Operand_1_Type;
    B    :        Operand_2_Type
  );

  --  Save and restore an object file
  procedure SaveOBJ (FileName : String);
  procedure RestoreOBJ (FileName : String);

  ------------------------------------
  --  Standard function operations  --
  ------------------------------------

  type SF_Code is (
    SF_Abs_Int,
    SF_Abs_Float,
    SF_T_Val,                   --  S'Val  : RM 3.5.5 (5)
    SF_T_Pos,                   --  S'Pos  : RM 3.5.5 (2)
    SF_T_Succ,                  --  S'Succ : RM 3.5 (22)
    SF_T_Pred,                  --  S'Pred : RM 3.5 (25)
    --  Numerical functions
    SF_Round_Float_to_Int,
    SF_Trunc_Float_to_Int,
    SF_Float_to_Duration,
    SF_Duration_to_Float,
    SF_Int_to_Duration,
    SF_Duration_to_Int,
    SF_Sin,
    SF_Cos,
    SF_Exp,
    SF_Log,
    SF_Sqrt,
    SF_Arctan,
    SF_EOF,
    SF_EOLN,
    SF_Random_Int,
    --  VString functions
    SF_String_to_VString,       --  +S        (S is a fixed-size string)
    SF_Literal_to_VString,      --  +"Hello"
    SF_Char_to_VString,         --  +'x'
    SF_Two_VStrings_Concat,     --  V1 & V2
    SF_VString_Char_Concat,     --  V & 'x'
    SF_Char_VString_Concat,     --  'x' & V
    SF_LStr_VString_Concat,     --  "Hello " & V
    --
    SF_VString_Int_Concat,      --  V & 123
    SF_Int_VString_Concat,      --  123 & V
    SF_VString_Float_Concat,    --  V & 3.14159
    SF_Float_VString_Concat,    --  3.14159 & V
    --
    SF_Element,
    SF_Length,
    SF_Slice,
    --
    SF_To_Lower_Char,
    SF_To_Upper_Char,
    SF_To_Lower_VStr,
    SF_To_Upper_VStr,
    SF_Index,
    SF_Int_Times_Char,
    SF_Int_Times_VStr,
    --
    SF_Trim_Left,
    SF_Trim_Right,
    SF_Trim_Both,
    --
    SF_Head,
    SF_Tail,
    SF_Starts_With,
    SF_Ends_With,
    --
    --  Ada.Calendar-like functions
    --
    SF_Time_Subtract,    --  T2 - T1 -> Duration
    SF_Duration_Add,
    SF_Duration_Subtract,
    SF_Year,
    SF_Month,
    SF_Day,
    SF_Seconds,
    --
    SF_Image_Ints,
    SF_Image_Floats,            --  "Nice" image
    SF_Image_Attribute_Floats,  --  Image attribute "as is" from Ada
    SF_Image_Times,
    SF_Image_Durations,
    SF_Integer_Value,
    SF_Float_Value,
    --
    SF_Argument,
    SF_Exists,  --  Ada.Directories-like
    SF_Get_Env,
    --
    --  Niladic functions (they have no arguments).
    --
    SF_Clock,
    SF_Random_Float,
    SF_Argument_Count,
    SF_Command_Name,
    SF_Directory_Separator,
    SF_Current_Directory,  --  Ada.Directories-like
    --
    SF_Get_Needs_Skip_Line  --  Informs whether Get from console needs Skip_Line
  );

  subtype SF_Niladic is SF_Code range SF_Clock .. SF_Get_Needs_Skip_Line;

  subtype SF_File_Information is SF_Code range SF_EOF .. SF_EOLN;

  -------------------------------------
  --  Standard procedure operations  --
  -------------------------------------

  type SP_Code is (
    SP_Create,
    SP_Open,
    SP_Append,
    SP_Close,
    --
    SP_Push_Abstract_Console,
    --
    SP_Get,
    SP_Get_Immediate,
    SP_Get_Line,
    SP_Get_F,
    SP_Get_Line_F,
    SP_Skip_Line,
    --
    SP_Put,
    SP_Put_Line,
    SP_Put_F,
    SP_Put_Line_F,
    SP_New_Line,
    --
    SP_Wait,
    SP_Signal,
    --
    SP_Quantum,
    SP_Priority,
    SP_InheritP,
    --
    --  Ada.Environment_Variables-like procedures
    --
    SP_Set_Env,
    --
    --  Ada.Directories-like procedures
    --
    SP_Copy_File,
    SP_Delete_File,
    SP_Rename,
    SP_Set_Directory,
    SP_Set_Exit_Status,
    --
    --  Other system procedures
    --
    SP_Shell_Execute_without_Result,
    SP_Shell_Execute_with_Result
  );

  subtype SP_Shell_Execute is SP_Code
    range SP_Shell_Execute_without_Result .. SP_Shell_Execute_with_Result;

end HAC_Sys.PCode;
