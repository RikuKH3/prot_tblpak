program prot_tblpak;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

procedure PackProt;
begin
  Writeln('Repacking are not supported yet!'); Readln; exit
end;

function StringListSortProc(List: TStringList; Index1, Index2: Integer): Integer;
var
  i1, i2: Integer;
begin
  i1 := StrToIntDef(List.Names[Index1], -1);
  i2 := StrToIntDef(List.Names[Index2], -1);
  Result := i1 - i2;
end;

procedure UnpackProt;
var
  MemoryStream1: TMemoryStream;
  FileStream1, FileStream2: TFileStream;
  StringList1: TStringList;
//StringArr: array of String;
  r4, r5, r6, r7, r8, r9, r10, r11, r26, r27, r28, ContentID, ContentPos, NumOfFiles, LongWord1, LongWord2: LongWord;
  HdrSize, BlockSize: Word;
  Byte1, ContentPkgNum, PkgCount: Byte;
  i, i2, x, y, z: Integer;
  InputFileNoext, OutFolder, OutName, OutExt, s, s2: String;
begin
  InputFileNoext := ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));
  if ParamCount > 1 then OutFolder := ExpandFileName(ParamStr(2)) else OutFolder := InputFileNoext;

  StringList1:=TStringList.Create;
  try
    MemoryStream1:=TMemoryStream.Create;
    try
      MemoryStream1.LoadFromFile(ParamStr(1));
      MemoryStream1.Position := 2;
      MemoryStream1.ReadBuffer(HdrSize, 2);
      MemoryStream1.ReadBuffer(NumOfFiles, 4);
      MemoryStream1.ReadBuffer(BlockSize, 2);
      PkgCount := 0;

      for LongWord1:=0 to NumOfFiles-1 do begin
        r26 := $1C;
        r27 := $14;
        r28 := 4;
        r6 := LongWord1;

        r4 := r6 + r6;
        r7 := r6 + r4;
        Inc(r4, r7);
        r4 := r4 shl 4;
        r7 := r4 - r7;
        r6 := r7 shr 3;
        r4 := r7 and 7;
        Inc(r6, HdrSize);
        r5 := 0;

        repeat
          r9 := 8 - r4;
          r8 := r9;
          if r26 < r8 then r8 := r26;
          r10 := -r8;
          r9 := 1 shl r9;
          r4 := r10 - r4;
          r10 := r6 + 1;
          Dec(r9);
          MemoryStream1.Position:=r6; MemoryStream1.ReadBuffer(Byte1,1); r6:=Byte1;
          Inc(r4, 8);
          Dec(r26, r8);
          r6 := r6 and r9;
          r6 := r6 shr r4;
          r4 := 0;
          r8 := r6 shl r26;
          r6 := r10;
          r5 := r5 or r8;
        until r26 = 0;

        ContentID := r5;

        r4 := r7 + $1C;
        r6 := r4 shr 3;
        r4 := r4 and 7;
        Inc(r6, HdrSize);
        r5 := r6;
        r6 := 0;

        repeat
          r9 := 8 - r4;
          r8 := r9;
          if r28 < r8 then r8 := r28;
          r10 := -r8;
          r9 := 1 shl r9;
          r4 := r10 - r4;
          r10 := r5 + 1;
          Dec(r9);
          MemoryStream1.Position:=r5; MemoryStream1.ReadBuffer(Byte1,1); r5:=Byte1;
          Inc(r4, 8);
          Dec(r28, r8);
          r5 := r5 and r9;
          r5 := r5 shr r4;
          r4 := 0;
          r8 := r5 shl r28;
          r5 := r10;
          r6 := r6 or r8;
        until r28 = 0;

        ContentPkgNum := r6;
        if ContentPkgNum > PkgCount then PkgCount := ContentPkgNum;

        r4 := r7 + $20;
        r8 := r27;
        r5 := r4 and 7;
        r4 := r4 shr 3;
        r27 := 0;
        Inc(r4, HdrSize);

        repeat
          r10 := 8 - r5;
          r9 := r10;
          if r8 < r9 then r9 := r8;
          r10 := 1 shl r10;
          r11 := -r9;
          Dec(r8, r9);
          Dec(r10);
          MemoryStream1.Position:=r4; MemoryStream1.ReadBuffer(Byte1,1); r9:=Byte1;
          r5 := r11 - r5;
          Inc(r4);
          r9 := r9 and r10;
          Inc(r5, 8);
          r9 := r9 shr r5;
          r5 := 0;
          r9 := r9 shl r8;
          r27 := r27 or r9;
        until r8 = 0;

        r27 := r27 * BlockSize;
        ContentPos := r27;

        r5 := r7 + $34;
        r4 := r5 shr 3;
        r5 := r5 and 7;
        Inc(r4, HdrSize);
        r8 := $19;
        r7 := 0;

        repeat
          r10 := 8 - r5;
          r9 := r10;
          if r8 < r9 then r9 := r8;
          r10 := 1 shl r10;
          r11 := -r9;
          Dec(r8, r9);
          Dec(r10);
          MemoryStream1.Position:=r4; MemoryStream1.ReadBuffer(Byte1,1); r9:=Byte1;
          r5 := r11 - r5;
          Inc(r4);
          r9 := r9 and r10;
          Inc(r5, 8);
          r9 := r9 shr r5;
          r5 := 0;
          r9 := r9 shl r8;
          r7 := r7 or r9;
        until r8 = 0;

        StringList1.Append(IntToStr(ContentPos) +'='+ IntToHex(ContentID,8) +';'+ IntToStr(ContentPkgNum) +';'+ IntToStr(r7));
      end;
    finally MemoryStream1.Free end;
    StringList1.CustomSort(StringListSortProc);

    s2 := IntToStr(NumOfFiles);
    i2 := Length(s2);
    if DirectoryExists(OutFolder) = False then ForceDirectories(OutFolder);
//  SetLength(StringArr, NumOfFiles);
    x := 0;
    for i:=0 to PkgCount do begin
      s := IntToStr(i);
      FileStream1:=TFileStream.Create(InputFileNoext+StringOfChar('0',2-Length(s))+s+'.pak', fmOpenRead or fmShareDenyWrite);
      try
        for LongWord2:=0 to NumOfFiles-1 do begin
          y := Pos(';', StringList1.ValueFromIndex[LongWord2]);
          s := Copy(StringList1.ValueFromIndex[LongWord2], y+1);
          z := Pos(';', s);
          if StrToInt(Copy(s, 1, z-1)) = i then begin
            OutName := Copy(StringList1.ValueFromIndex[LongWord2], 1, y-1);

            FileStream1.Position := StrToInt64(StringList1.Names[LongWord2]);
            FileStream1.ReadBuffer(LongWord1, 4);
            case LongWord1 of
              $474E5089: OutExt:='.png';
              $5367674F: OutExt:='.ogg';
              $00011804: OutExt:='.psb';
              $46464952: OutExt:='.at3'
              else OutExt:='.dat'
            end;
            FileStream1.Position := FileStream1.Position - 4;

            LongWord1 := StrToInt64(Copy(s, z+1));
            s := IntToStr(x+1);
            s := StringOfChar('0', i2-Length(s)) + s;
            Writeln('['+s+'/'+s2+'] '+OutName+OutExt);
            FileStream2:=TFileStream.Create(OutFolder+'\'+s+'_'+OutName+OutExt, fmCreate or fmOpenWrite or fmShareDenyWrite);
            try
              FileStream2.CopyFrom(FileStream1, LongWord1)
            finally FileStream2.Free end;

//          StringArr[x] := StringList1[LongWord2];
            Inc(x)
          end;
        end;
      finally FileStream1.Free end;
    end;

//  for i:=0 to StringList1.Count-1 do StringList1[i] := StringArr[i];
//  StringList1.SaveToFile('out.txt');
  finally StringList1.Free end;
end;

begin
  try
    Writeln('Prototype TBL-PAK Unpacker/Packer v1.0 by RikuKH3');
    Writeln('-------------------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input tbl file or folder> [output tbl file or folder]'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))=0 then PackProt else UnpackProt;
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
