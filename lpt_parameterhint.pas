unit lpt_parameterhint;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Graphics, SynEditKeyCmds, LCLType,
  lpt_editor, lpt_parser;

type
  TLapeTools_ParameterHint = class;

  TLapeTools_ParameterHint_Method = class
  protected
    FName: String;
    FResult: String;
    FParameters: array of array of TDeclaration_Parameter;
  public
    function Draw(Canvas: TCanvas; X, Y, Current: Int32): Int32;
    function Measure(Canvas: TCanvas): Int32;

    constructor Create(Header: TDeclaration_MethodHeader);
  end;
  TLapeTools_ParameterHint_Methods = array of TLapeTools_ParameterHint_Method;

  TLapeTools_ParameterHint_Form = class(THintWindow)
  protected
    FMethods: TLapeTools_ParameterHint_Methods;
    FIndex: Int32;

    function GetMethodCount: Int32;
  public
    property Index: Int32 read FIndex write FIndex;
    property MethodCount: Int32 read GetMethodCount;

    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
    procedure Show;

    procedure Clear;

    procedure Add(Header: TDeclaration_MethodHeader); overload;
    procedure Add(Methods: TDeclaration_Methods); overload;
  end;

  TLapeTools_ParameterHint = class(TComponent)
  protected
    FParser: TLapeTools_Parser;
    FEditor: TLapeTools_Editor;
    FForm: TLapeTools_ParameterHint_Form;
    FStartXY: TPoint;
    FExpression: String;
    FExpressionStartXY: TPoint;
    FExpressionEndXY: TPoint;

    procedure DoApplicationLostFocus(Sender: TObject);
    procedure DoCommandProcessor(var Command: TSynEditorCommand; Char: TUTF8Char);

    procedure SetEditor(Value: TLapeTools_Editor);
  public
    property Editor: TLapeTools_Editor read FEditor write SetEditor;

    procedure Execute(X, Y: Int32);

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  lpparser;

function TLapeTools_ParameterHint_Method.Draw(Canvas: TCanvas; X, Y, Current: Int32): Int32;

  procedure DrawText(Text: String; Bold: Boolean = False);
  begin
    with Canvas do
    begin
      Font.Color := clBlack;
      Font.Bold := Bold;

      TextOut(X, Y, Text);

      X := X + TextWidth(Text);
      if Bold then
        X := X + 1;
    end;
  end;

var
  i, j, h, c: Int32;
  Bold: Boolean;
begin
  Result := X;
  c := 0;

  DrawText(FName);
  DrawText('(');

  for i := 0 to High(FParameters) do
  begin
    h := High(FParameters[i]);
    Bold := False;

    for j := 0 to h do
      if (c + j) = Current then
        Bold := True;

    case FParameters[i][0].Modifier of
      pmConst: DrawText('const ', Bold);
      pmConstRef: DrawText('const ', Bold);
      pmVar: DrawText('var ', Bold);
      pmOut: DrawText('out ', Bold);
    end;

    for j := 0 to h do
    begin
      if (c = Current) then
        DrawText(FParameters[i][j].Name.Text, True)
      else
        DrawText(FParameters[i][j].Name.Text);

      if (j < h) then
        DrawText(', ');

      Inc(c);
    end;

    if (FParameters[i][0].VarType <> nil) then
    begin
      DrawText(': ');
      DrawText(FParameters[i][0].VarType.Text, Bold)
    end;

    if (FParameters[i][0].Value <> nil) then
    begin
      DrawText(' = ');
      DrawText(FParameters[i][0].Value.Text, Bold);
    end;

    if (i < High(FParameters)) then
      DrawText('; ');
  end;

  DrawText(')');

  if (FResult <> '') then
    DrawText(': ' + FResult);

  Result := X - Result;
end;

function TLapeTools_ParameterHint_Method.Measure(Canvas: TCanvas): Int32;
begin
  Result := Draw(Canvas, 0, 0, -1) + 15;
end;

constructor TLapeTools_ParameterHint_Method.Create(Header: TDeclaration_MethodHeader);
var
  i: Int32;
begin
  if (Header.Name <> nil) then
    FName := Header.Name.Text;
  if (Header.Result <> nil) then
    FResult := Header.Result.Text;

  with Header do
    for i := 0 to Parameters.Count - 1 do
    begin
      if (i = 0) or (Parameters.Get(i).Group <> Parameters.Get(i - 1).Group) then
        SetLength(FParameters, Length(FParameters) + 1);

      SetLength(FParameters[High(FParameters)], Length(FParameters[High(FParameters)]) + 1);
      FParameters[High(FParameters)][High(FParameters[High(FParameters)])] := Parameters.Get(i);
    end;
end;

procedure TLapeTools_ParameterHint_Form.Clear;
begin
  while Length(FMethods) > 0 do
  begin
    FMethods[High(FMethods)].Free();

    SetLength(FMethods, Length(FMethods) - 1);
  end;
end;

procedure TLapeTools_ParameterHint_Form.Add(Header: TDeclaration_MethodHeader);
begin
  SetLength(FMethods, Length(FMethods) + 1);
  FMethods[High(FMethods)] := TLapeTools_ParameterHint_Method.Create(Header);
end;

procedure TLapeTools_ParameterHint_Form.Add(Methods: TDeclaration_Methods);
var
  i: Int32;
begin
  for i := 0 to High(Methods) do
    Add(Methods[i].Header);
end;

function TLapeTools_ParameterHint_Form.GetMethodCount: Int32;
begin
  Result := Length(FMethods);
end;

procedure TLapeTools_ParameterHint_Form.EraseBackground(DC: HDC);
begin
  { nothing }
end;

procedure TLapeTools_ParameterHint_Form.Paint;
var
  i: Int32;
begin
  Canvas.Pen.Color := clBlack;
  Canvas.Brush.Color := $F0F0F0;
  Canvas.Rectangle(ClientRect);

  for i := 0 to High(FMethods) do
    FMethods[i].Draw(Canvas, BorderWidth, ((i * Canvas.TextHeight('TaylorSwift')) + BorderWidth) - 1, FIndex);
end;

procedure TLapeTools_ParameterHint_Form.Show;
var
  i: Int32;
begin
  if (Length(FMethods) > 0) then
  begin
    Height := (Length(FMethods) * Canvas.TextHeight('TaylorSwift')) + (BorderWidth * 2);
    Width := 0;

    for i := 0 to High(FMethods) do
      if (FMethods[i].Measure(Canvas) > Width) then
        Width := FMethods[i].Measure(Canvas);

    Width := Width + (BorderWidth * 2);
    Top := Top - Height;

    inherited Show();
  end else
    Hide();
end;

procedure TLapeTools_ParameterHint.DoApplicationLostFocus(Sender: TObject);
begin
  FForm.Hide();
end;

procedure TLapeTools_ParameterHint.DoCommandProcessor(var Command: TSynEditorCommand; Char: TUTF8Char);

  procedure Show(XY: TPoint);
  begin
    if (FParser <> nil) then
      FParser.Free();
    FParser := FEditor.GetParser(True);

    FStartXY := XY;

    FExpressionStartXY := FStartXY;
    FExpressionEndXY := FStartXY;
    FExpression := FEditor.GetExpression(FExpressionStartXY, FExpressionEndXY);

    with FEditor.ClientToScreen(FEditor.RowColumnToPixels(FExpressionStartXY)) do
      Execute(X, Y);

    FForm.Index := FEditor.GetParameterIndex(FStartXY);
    FForm.Paint();
  end;

  procedure Update;
  var
    XY: TPoint;
  begin
    if FForm.Visible then
    begin
      if (not FEditor.GetParameterStart(XY)) then
        FForm.Visible := False
      else
      if (XY.X <> FStartXY.X) or (XY.Y <> FStartXY.Y) then
        Show(XY)
      else
      begin
        FForm.Index := FEditor.GetParameterIndex(XY);
        FForm.Paint();
      end;
    end;
  end;

var
  XY: TPoint;
begin
  case Command of
    lecEscape:
      if FForm.Visible then
        FForm.Visible := False;

    lecCaretChange:
      if FForm.Visible then
        Update();

    lecParameterHint:
      if FEditor.GetParameterStart(XY) then
        Show(XY);

    lecFocusLost:
      if FForm.Visible and (GetParentForm(FEditor).ActiveControl <> FEditor) then
        FForm.Visible := False;

    lecScroll:
      if FForm.Visible then
        FForm.Visible := False;
  end;
end;

procedure TLapeTools_ParameterHint.SetEditor(Value: TLapeTools_Editor);
begin
  FEditor := Value;
  FEditor.AddCommandProcessor(@DoCommandProcessor);
end;

procedure TLapeTools_ParameterHint.Execute(X, Y: Int32);

  procedure AddMethod(Map: TDeclarationMap; Method: TDeclaration_Method);
  begin
    if Method.Header.MethodType in [mtProcedureOfObject, mtFunctionOfObject] then
      FForm.Add(Map.GetMethods(Method.Header.ObjectName.Text + '.' + Method.Header.Name.Text))
    else
      FForm.Add(Map.GetMethods(Method.Header.Name.Text));
  end;

var
  Declaration: TDeclaration;
begin
  if (not FForm.Font.IsEqual(FEditor.Font)) then
    FForm.Font := FEditor.Font;
  FForm.Clear();

  if (Pos('.', FExpression) > 0) then
    Declaration := FParser.ParseExpression(FExpression)
  else
    Declaration := FParser.Find(FExpression);

  if (Declaration <> nil) and (Declaration is TDeclaration_Variable) and (TDeclaration_Variable(Declaration).VarType <> nil) then
    Declaration := FParser.GetType(TDeclaration_Variable(Declaration).VarType);

  if (Declaration <> nil) then
  begin
    if (Declaration is TDeclaration_Method) then
    begin
      if (FParser.InMethod <> nil) then
        AddMethod(FParser.InMethod.Locals, Declaration as TDeclaration_Method);

      AddMethod(FParser.Map, Declaration as TDeclaration_Method);
    end else
    if (Declaration is TDeclaration_Type_Method) then
      FForm.Add(TDeclaration_Type_Method(Declaration).Header)
  end;

  if (FForm.MethodCount > 0) then
  begin
    FForm.Left := X;
    FForm.Top := Y;
    FForm.Show();
  end else
    FForm.Hide();

  if FEditor.CanFocus() then
    FEditor.SetFocus();
end;

constructor TLapeTools_ParameterHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FForm := TLapeTools_ParameterHint_Form.Create(Self);
  FForm.ShowInTaskBar := stNever;
  FForm.BorderWidth := 3;
  FForm.DoubleBuffered := True;

  Application.AddOnDeactivateHandler(@DoApplicationLostFocus);
end;

destructor TLapeTools_ParameterHint.Destroy;
begin
  if (FParser <> nil) then
    FParser.Free();

  FForm.Clear();

  Application.RemoveOnDeactivateHandler(@DoApplicationLostFocus);

  inherited Destroy;
end;

end.

