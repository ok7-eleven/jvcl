{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvgSplit.PAS, released on 2003-01-15.

The Initial Developer of the Original Code is Andrey V. Chudin,  [chudin@yandex.ru]
Portions created by Andrey V. Chudin are Copyright (C) 2003 Andrey V. Chudin.
All Rights Reserved.

Contributor(s):
Michael Beck [mbeck@bigfoot.com].

Last Modified:  2003-01-15

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

Known Issues:
-----------------------------------------------------------------------------}

{$I JVCL.INC}

unit JvgSplit;

interface
uses
  Windows, Messages, Classes, Controls, Graphics, JvComponent, JvgTypes, JVCLVer,
  JvgCommClasses, JvgUtils, ExtCtrls;

type
  TJvgSplitter = class(TSplitter)
  private
    FAboutJVCL: TJVCLAboutInfo;
    FHotTrack: boolean;
    FTrackCount: integer;
    FActive: boolean;
    FDisplace: boolean;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMMouseDblClick(var Message: TMessage); message WM_LBUTTONDBLCLK;
    procedure SetTrackCount(const Value: integer);
    procedure UpdateControlSize;
    function FindControl: TControl;
    procedure PrepareMarcs(Align: TAlign; var pt1, pt2, pt3, pt4, pt5, pt6: TPoint);
    procedure SetDisplace(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Paint; override;
  published
    property AboutJVCL: TJVCLAboutInfo read FAboutJVCL write FAboutJVCL stored False;
    property HotTrack: boolean read FHotTrack write FHotTrack default True;
    property TrackCount: integer read FTrackCount write SetTrackCount default 20;
    property Displace: boolean read FDisplace write SetDisplace default True;
  end;

implementation

uses
  JvThemes;

{~~~~~~~~~~~~~~~~~~~~~~~~~}

procedure TJvgSplitter.Paint;
var
  i: integer;
  sColor: TColor;
  pt1, pt2, pt3, pt4, pt5, pt6: TPoint;
  R, R1, R2: TRect;
begin
  with Canvas do
  begin

    Brush.Color := Self.Color;
    DrawThemedBackground(Self, Canvas, ClientRect);

    if (Align = alBottom) or (Align = alTop) then
    begin
      R1 := Classes.Bounds((Width - FTrackCount * 4) div 2, 0, 3, 3);
      R2 := Classes.Bounds((Width - FTrackCount * 4) div 2, 3, 3, 3);
    end
    else
    begin
      R1 := Classes.Bounds(0, (Height - FTrackCount * 4) div 2, 3, 3);
      R2 := Classes.Bounds(3, (Height - FTrackCount * 4) div 2, 3, 3);
    end;

    for i := 0 to FTrackCount - 1 do
    begin
{$IFDEF JVCLThemesEnabled}
      if FActive and HotTrack and ThemeServices.ThemesEnabled then
        sColor := RGB(100, 100, 100)
      else
{$ENDIF}
      if FActive and HotTrack then
        sColor := clBlack
      else
        sColor := clBtnShadow;

      R := R1;
      Frame3D(Canvas, R, clBtnHighlight, sColor, 1);
      R := R2;
      Frame3D(Canvas, R, clBtnHighlight, sColor, 1);

      if (Align = alBottom) or (Align = alTop) then
      begin
        OffsetRect(R1, 4, 0);
        OffsetRect(R2, 4, 0);
      end
      else
      begin
        OffsetRect(R1, 0, 4);
        OffsetRect(R2, 0, 4);
      end;

    end;
    if FDisplace then
    begin
      PrepareMarcs(Align, pt1, pt2, pt3, pt4, pt5, pt6);
      if FActive then
        Canvas.Brush.Color := clGray
      else
        Canvas.Brush.Color := clWhite;
      Canvas.Polygon([pt1, pt2, pt3]);
      Canvas.Polygon([pt4, pt5, pt6]);
    end;
  end;
end;

procedure TJvgSplitter.PrepareMarcs(Align: TAlign; var pt1, pt2, pt3, pt4, pt5, pt6: TPoint);
begin
  case Align of
    alRight:
      begin
        pt1.x := 1;
        pt1.y := (Height - FTrackCount * 4) div 2 - 30;
        pt2.x := 1;
        pt2.y := pt1.y + 6;
        pt3.x := 4;
        pt3.y := pt1.y + 3;

        pt4.x := 1;
        pt4.y := (Height - FTrackCount * 4) div 2 + FTrackCount * 4 + 30 -
          7;
        pt5.x := 1;
        pt5.y := pt4.y + 6;
        pt6.x := 4;
        pt6.y := pt4.y + 3;
      end;
    alLeft:
      begin
        pt1.x := 3;
        pt1.y := (Height - FTrackCount * 4) div 2 - 30;
        pt2.x := 3;
        pt2.y := pt1.y + 6;
        pt3.x := 0;
        pt3.y := pt1.y + 3;

        pt4.x := 3;
        pt4.y := (Height - FTrackCount * 4) div 2 + FTrackCount * 4 + 30 -
          7;
        pt5.x := 3;
        pt5.y := pt4.y + 6;
        pt6.x := 0;
        pt6.y := pt4.y + 3;
      end;
    alTop:
      begin
        pt1.x := (Width - FTrackCount * 4) div 2 - 30;
        pt1.y := 4;
        pt2.x := pt1.x + 6;
        pt2.y := 4;
        pt3.x := pt1.x + 3;
        pt3.y := 1;

        pt4.x := (Width - FTrackCount * 4) div 2 + FTrackCount * 4 + 30 - 7;
        pt4.y := 4;
        pt5.x := pt4.x + 6;
        pt5.y := 4;
        pt6.x := pt4.x + 3;
        pt6.y := 1;
      end;
    alBottom:
      begin
        pt1.x := (Width - FTrackCount * 4) div 2 - 30;
        pt1.y := 1;
        pt2.x := pt1.x + 6;
        pt2.y := 1;
        pt3.x := pt1.x + 3;
        pt3.y := 4;

        pt4.x := (Width - FTrackCount * 4) div 2 + FTrackCount * 4 + 30 - 7;
        pt4.y := 1;
        pt5.x := pt4.x + 6;
        pt5.y := 1;
        pt6.x := pt4.x + 3;
        pt6.y := 4;
      end;
  end;
end;

procedure TJvgSplitter.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FActive := true;
  Invalidate;
end;

procedure TJvgSplitter.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FActive := false;
  Invalidate;
end;

constructor TJvgSplitter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  IncludeThemeStyle(Self, [csParentBackground]);
  //..defaults
  Width := 6;
  FHotTrack := true;
  FTrackCount := 20;
  FDisplace := true;
end;

procedure TJvgSplitter.SetTrackCount(const Value: integer);
begin
  FTrackCount := Value;
  Invalidate;
end;

procedure TJvgSplitter.WMMouseDblClick(var Message: TMessage);
begin
  if FDisplace then
    UpdateControlSize;
end;

// (rom) has to be cleaned up!!!!
var
  FKeepSize: Integer = 0; (* +++ RDB --- *)

procedure TJvgSplitter.UpdateControlSize;
const
  cNewSize = 0;
var
  FControl: TControl;
begin
  FControl := FindControl;
  if not Assigned(FControl) then
    Exit;
  begin
    if FKeepSize = 0 then
    begin
      case Align of
        alLeft:
          begin
            FKeepSize := FControl.Width;
            FControl.Width := cNewSize;
          end;
        alTop:
          begin
            FKeepSize := FControl.Height;
            FControl.Height := cNewSize;
          end;
        alRight:
          begin
            FKeepSize := FControl.Width;
            Parent.DisableAlign;
            try
              FControl.Left := FControl.Left + (FControl.Width - cNewSize);
              FControl.Width := cNewSize;
            finally
              Parent.EnableAlign;
            end;
          end;
        alBottom:
          begin
            fKeepSize := FControl.Height;
            Parent.DisableAlign;
            try
              FControl.Top := FControl.Top + (FControl.Height - cNewSize);
              FControl.Height := cNewSize;
            finally
              Parent.EnableAlign;
            end;
          end;
      end;
    end
    else (* ++++ RDB +++ *)
    begin
      case Align of
        alLeft:
          begin
            FControl.Width := FKeepSize;
          end;
        alTop:
          begin
            FControl.Height := FKeepSize;
          end;
        alRight:
          begin
            Parent.DisableAlign;
            try
              FControl.Left := FControl.Left + (FControl.Width - FKeepSize);
              FControl.Width := FKeepSize;
            finally
              Parent.EnableAlign;
            end;
          end;
        alBottom:
          begin
            Parent.DisableAlign;
            try
              FControl.Top := FControl.Top + (FControl.Height - FKeepSize);
              FControl.Height := FKeepSize;
            finally
              Parent.EnableAlign;
            end;
          end;
      end;
      FKeepSize := 0; (* --- RDB --- *)
    end;
    Update;
    if Assigned(OnMoved) then
      OnMoved(Self);
  end;
end;

function TJvgSplitter.FindControl: TControl;
var
  P: TPoint;
  I: Integer;
  R: TRect;
begin
  Result := nil;
  P := Point(Left, Top);
  case Align of
    alLeft: Dec(P.X);
    alRight: Inc(P.X, Width);
    alTop: Dec(P.Y);
    alBottom: Inc(P.Y, Height);
  else
    Exit;
  end;
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Result := Parent.Controls[I];
    if Result.Visible and Result.Enabled then
    begin
      R := Result.BoundsRect;
      if (R.Right - R.Left) = 0 then
        if Align in [alTop, alLeft] then
          Dec(R.Left)
        else
          Inc(R.Right);
      if (R.Bottom - R.Top) = 0 then
        if Align in [alTop, alLeft] then
          Dec(R.Top)
        else
          Inc(R.Bottom);
      if PtInRect(R, P) then
        Exit;
    end;
  end;
  Result := nil;
end;

procedure TJvgSplitter.SetDisplace(const Value: Boolean);
begin
  FDisplace := Value;
  Invalidate;
end;

end.

