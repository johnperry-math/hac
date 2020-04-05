--  This is the package containing all specifications of types and support
--  routines for HAC. So far all HAC programs must have "with" and "use"
--  of this package.
--
--  Note: this is kept for early stages. At some point HAC_Pack won't
--  be used anymore. The package is compilable by a real Ada compiler like
--  GNAT, so the test programs can be run on both HAC and GNAT.

package HAC_Pack is

   type Real is digits 15;

   type Semaphore is new Integer; -- private;

   -- Absolute Value - SMA used ABS instead of "ABS" (operator)... TBA !!
   -- function   ABS       ( I : INTEGER   ) return INTEGER;
   -- function   ABS       ( F : FLOAT     ) return FLOAT;

   -- Square (!! to be removed: **2 in Ada)
   function   Sqr       ( I : Integer   ) return Integer;
   function   Sqr       ( F : Real     ) return Real;

   function   "**"      (f1, f2 : Real)  return Real;

   -- Square Root
   function   Sqrt      ( I : Integer   ) return Real;
   function   Sqrt      ( F : Real     ) return Real;

   -- Odd Valued
   function   Odd       ( I : Integer   ) return Boolean;

   -- Integer to Character
   function   ASCII     ( I : Integer   ) return Character;

   -- Character to Integer
   function   Ord       ( C : Character ) return Integer;

   -- Next Character
   function   Succ      ( C : Character ) return Character;

   -- Previous Character
   function   Pred      ( C : Character ) return Character;

   -- Round to an Integer
   function   Round     ( F : Real     ) return Integer;

   -- Truncate
   function   Trunc     ( F : Real     ) return Integer;

   -- Trigonometric Functions     w/ arguments in radians
   function   Sin       ( I : Integer   ) return Real;
   function   Sin       ( F : Real     ) return Real;
   function   Cos       ( I : Integer   ) return Real;
   function   Cos       ( F : Real     ) return Real;
   function   ArcTan    ( I : Integer   ) return Real;
   function   ArcTan    ( F : Real     ) return Real;

   -- Exponential Functions
   function   Log       ( I : Integer   ) return Real;
   function   Log       ( F : Real     ) return Real;
   function   Exp       ( I : Integer   ) return Real;
   function   Exp       ( F : Real     ) return Real;

   -- Random Integer      from 0 to I
   function   Random    ( I : Integer   ) return Integer;
   function   Random    ( I : Integer   ) return Real;

   -- Get
   procedure  Get       ( C : out Character);
   procedure  Get       ( I : out Integer  );
   procedure  Get       ( F : out Real    );
   procedure  Get       ( B : out Boolean  );

   -- Get and then move file pointer to next line
   procedure  Get_Line  ( C : out Character);
   procedure  Get_Line  ( I : out Integer  );
   procedure  Get_Line  ( F : out Real    );
   procedure  Get_Line  ( B : out Boolean  );

   subtype Width is Positive;
   subtype Decimals is Positive;

   -- Put
   procedure  Put       ( C : in  Character);
   procedure  Put       ( I : in  Integer  );
   procedure  Put       ( I : in  Integer;  W:  Width);
   procedure  Put       ( F : in  Real    );
   procedure  Put       ( F : in  Real;    W:  Width; D : Decimals);
   procedure  Put       ( B : in  Boolean  );
   procedure  Put       ( S : in  String   );

   -- Put and then NEW_LINE ( !! it is the same as Ada.Text_IO only for S )
   procedure  Put_Line  ( C : in  Character);
   procedure  Put_Line  ( I : in  Integer  );
   procedure  Put_Line  ( I : in  Integer; W:  Width);
   procedure  Put_Line  ( F : in  Real    );
   procedure  Put_Line  ( F : in  Real;   W:  Width; D : Decimals);
   procedure  Put_Line  ( B : in  Boolean  );
   procedure  Put_Line  ( S : in  String   );

   -- Mark End of Line
   procedure  New_Line                      ;

   procedure  CursorAt (X, Y: Integer);

   -- Semaphore Procedures
   procedure  Wait      ( S : Semaphore    );
   procedure  Signal    ( S : Semaphore    );

private

   -- type       SEMAPHORE is new INTEGER;

end HAC_Pack;