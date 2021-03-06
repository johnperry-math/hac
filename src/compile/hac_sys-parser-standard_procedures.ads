with HAC_Sys.PCode;

private package HAC_Sys.Parser.Standard_Procedures is

  --  NB: Some of the supplied subprograms may disappear when modularity,
  --  Ada.Text_IO etc. will be implemented, as well as overloading.

  procedure Standard_Procedure (
    CD      : in out Compiler_Data;
    Level   :        PCode.Nesting_level;
    FSys    :        Defs.Symset;
    Code    :        PCode.SP_Code
  );

end HAC_Sys.Parser.Standard_Procedures;
