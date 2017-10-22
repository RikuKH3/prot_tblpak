program prot_tblpak;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

function HexToInt(HexStr: string): Integer;
var
  w: Word;
  i: Integer;
begin
  Result:=0;
  for i:=1 to Length(HexStr) do begin
    w:=Word(HexStr[i]);
    case w of
      48..57: Result:=(Result shl 4)+(w-48);
      65..70,97..102: Result:=(Result shl 4)+(w-55)
      else begin Result:=0; break end
    end;
  end;
end;

function StringListSortProc(List: TStringList; Index1, Index2: Integer): Integer;
var
  i1, i2: Int64;
begin
  i1 := StrToInt64(List.Names[Index1]);
  i2 := StrToInt64(List.Names[Index2]);
  Result := i1 - i2;
end;

procedure PackProt;
label
  JumpPoint1;
const
  PakMagic: LongWord = $100144;
  ZeroByte: Byte = 0;
var
  FileStream1, FileStream2: TFileStream;
  MemoryStream1: TMemoryStream;
  StringList1, StringList2: TStringList;
  HdrUnk2, PakID, NormalSize, PaddedSize, PakPos, LongWord1: LongWord;
  HdrMagic, HdrSize, HdrUnk1, BlockSize: Word;
  i, x: Integer;
  PkgCount, XLen, XBits: Byte;
  JumpFlag: Boolean;
  InputDir, OutFile, OutFileNoext, s, s2: String;
begin
  InputDir := ExpandFileName(StringReplace(ParamStr(1),'/','\',[rfReplaceAll]));
  repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');
  if ParamCount>1 then begin
    OutFile := ExpandFileName(ParamStr(2));
    OutFileNoext := Copy(OutFile,1,Length(OutFile)-Length(ExtractFileExt(OutFile)));
    OutFile := OutFileNoext+'.tbl';
  end else begin
    OutFile := InputDir+'.tbl';
    OutFileNoext := InputDir;
  end;

  StringList1:=TStringList.Create;
  try
    StringList1.NameValueSeparator := ';';
    StringList2:=TStringList.Create;
    try
      StringList2.LoadFromFile(InputDir+'\filelist.txt');
      for i:=0 to StringList2.Count-1 do if Length(StringList2[i]) > 0 then StringList1.Append(StringList2[i]);
    finally StringList2.Free end;
    x:=0; for i:=0 to StringList1.Count-1 do begin x:=Pos('[',StringList1[i]); if x>0 then break end;
    s := Copy(StringList1[i], x+1);
    StringList1.Delete(i);
    x := Pos(';', s);
    HdrMagic := StrToInt(Copy(s,1,x-1));
    s := Copy(s, x+1);
    x := Pos(';', s);
    HdrSize := StrToInt(Copy(s,1,x-1));
    s := Copy(s, x+1);
    x := Pos(';', s);
    BlockSize := StrToInt(Copy(s,1,x-1));
    s := Copy(s, x+1);
    x := Pos(';', s);
    HdrUnk1 := StrToInt(Copy(s,1,x-1));
    s := Copy(s, x+1);
    if HdrSize >= $20 then begin
      x := Pos(';', s);
      HdrUnk2 := StrToInt64(Copy(s,1,x-1));
      s := Copy(s, x+1);
      PakID := StrToInt64(Copy(s,1,Pos(']',s)-1));
    end else HdrUnk2 := StrToInt64(Copy(s,1,Pos(']',s)-1));

    s2 := IntToStr(StringList1.Count);
    x  := Length(s2);

    i := 0;
    PkgCount := 0;
    JumpPoint1:
      JumpFlag := False;
      s := IntToStr(PkgCount);
      FileStream1:=TFileStream.Create(OutFileNoext+StringOfChar('0',2-Length(s))+s+'.pak', fmCreate or fmOpenWrite or fmShareDenyWrite);
      try
        if HdrSize >= $20 then begin FileStream1.WriteBuffer(PakMagic,4); FileStream1.WriteBuffer(PakID,4); if BlockSize>1 then FileStream1.Size:=BlockSize end;
        for i:=i to StringList1.Count-1 do begin
          PakPos := FileStream1.Position;

          FileStream2:=TFileStream.Create(InputDir+'\'+StringList1.Names[i], fmOpenRead or fmShareDenyWrite);
          try
            NormalSize := FileStream2.Size;
            if BlockSize > 1 then begin
              PaddedSize := NormalSize mod BlockSize;
              if PaddedSize > 0 then PaddedSize := NormalSize + BlockSize - PaddedSize else PaddedSize := NormalSize;
            end else PaddedSize := NormalSize;
            if FileStream1.Size+PaddedSize > 2147483647 then begin Inc(PkgCount); JumpFlag:=True; break end;
            s := IntToStr(i+1);
            s := StringOfChar('0', x-Length(s)) + s;
            Writeln('['+s+'/'+s2+'] ', StringList1.Names[i]);
            FileStream1.CopyFrom(FileStream2, NormalSize);
          finally FileStream2.Free end;

          FileStream1.Size := PakPos + PaddedSize;
          if BlockSize > 1 then PakPos:=PakPos div BlockSize;
          StringList1[i] := StringList1.ValueFromIndex[i] +';'+ IntToStr(PakPos) +':'+ IntToStr(NormalSize) +'*'+ IntToStr(PkgCount);
        end;
      finally FileStream1.Free end;
      if JumpFlag then goto JumpPoint1;

    StringList1.CustomSort(StringListSortProc);
    MemoryStream1:=TMemoryStream.Create;
    try
      MemoryStream1.WriteBuffer(HdrMagic, 2);
      MemoryStream1.WriteBuffer(HdrSize, 2);
      LongWord1 := StringList1.Count;
      MemoryStream1.WriteBuffer(LongWord1, 4);
      MemoryStream1.WriteBuffer(BlockSize, 2);
      MemoryStream1.WriteBuffer(HdrUnk1, 2);
      MemoryStream1.WriteBuffer(HdrUnk2, 4);
      if HdrSize >= $20 then MemoryStream1.WriteBuffer(PakID,4);
      for i:=1 to HdrSize-MemoryStream1.Size do MemoryStream1.WriteBuffer(ZeroByte,1);

      XBits := 0;
      XLen  := 0;
      for x:=0 to StringList1.Count-1 do begin
        i := Pos(':', StringList1.ValueFromIndex[x]);
        PakPos := StrToInt64(Copy(StringList1.ValueFromIndex[x], 1, i-1));
        s := Copy(StringList1.ValueFromIndex[x], i+1);
        i := Pos('*', s);
        NormalSize := StrToInt64(Copy(s, 1, i-1));
        LongWord1 := StrToInt64(StringList1.Names[x]) shl 4 or StrToInt(Copy(s, i+1));

        for i:=31 downto 0 do begin
          XBits := (XBits shl 1) or (LongWord1 shr i and 1);
          if XLen=7 then begin
            MemoryStream1.WriteBuffer(XBits, 1);
            XBits := 0;
            XLen  := 0;
          end else Inc(XLen)
        end;

        for i:=19 downto 0 do begin
          XBits := (XBits shl 1) or (PakPos shr i and 1);
          if XLen=7 then begin
            MemoryStream1.WriteBuffer(XBits, 1);
            XBits := 0;
            XLen  := 0;
          end else Inc(XLen)
        end;

        for i:=24 downto 0 do begin
          XBits := (XBits shl 1) or (NormalSize shr i and 1);
          if XLen=7 then begin
            MemoryStream1.WriteBuffer(XBits, 1);
            XBits := 0;
            XLen  := 0;
          end else Inc(XLen)
        end;
      end;
      if XLen > 0 then begin XBits := XBits shl (8 - XLen); MemoryStream1.WriteBuffer(XBits, 1) end;

      MemoryStream1.SaveToFile(OutFile);
    finally MemoryStream1.Free end;
  finally StringList1.Free end;
end;

procedure UnpackProt;
var
  MemoryStream1: TMemoryStream;
  FileStream1, FileStream2: TFileStream;
  StringList1: TStringList;
  StringArr: array of String;
  r4, r5, r6, r7, r8, r9, r10, r11, r26, r27, r28, ContentID, ContentPos, NumOfFiles, LongWord1, LongWord2: LongWord;
  HdrSize, BlockSize, Word1: Word;
  Byte1, ContentPkgNum, PkgCount: Byte;
  i, i2, x, y, z: Integer;
  InputFileNoext, OutFolder, OutName, OutExt, Header, s, s2: String;
begin
  InputFileNoext := ExpandFileName(Copy(ParamStr(1),1,Length(ParamStr(1))-Length(ExtractFileExt(ParamStr(1)))));
  if ParamCount > 1 then OutFolder := ExpandFileName(ParamStr(2)) else OutFolder := InputFileNoext;

  StringList1:=TStringList.Create;
  try
    MemoryStream1:=TMemoryStream.Create;
    try
      MemoryStream1.LoadFromFile(ParamStr(1));
      MemoryStream1.ReadBuffer(Word1, 2);
      Header := IntToStr(Word1);
      MemoryStream1.ReadBuffer(HdrSize, 2);
      Header := Header+';'+IntToStr(HdrSize);
      MemoryStream1.ReadBuffer(NumOfFiles, 4);
      MemoryStream1.ReadBuffer(BlockSize, 2);
      Header := Header+';'+IntToStr(BlockSize);
      MemoryStream1.ReadBuffer(Word1, 2);
      Header := Header+';'+IntToStr(Word1);
      MemoryStream1.ReadBuffer(LongWord1, 4);
      Header := Header+';'+IntToStr(LongWord1);
      if HdrSize >= $20 then begin MemoryStream1.Position:=$10; MemoryStream1.ReadBuffer(LongWord1,4); Header:=Header+';'+IntToStr(LongWord1) end;
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

        ContentPos := r27 * BlockSize;

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
    SetLength(StringArr, NumOfFiles);
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
            Writeln('['+s+'/'+s2+'] '+s+'_'+OutName+OutExt);
            FileStream2:=TFileStream.Create(OutFolder+'\'+s+'_'+OutName+OutExt, fmCreate or fmOpenWrite or fmShareDenyWrite);
            try
              FileStream2.CopyFrom(FileStream1, LongWord1)
            finally FileStream2.Free end;

            StringArr[x] := s+'_'+OutName+OutExt+';'+IntToStr(HexToInt(OutName));
            Inc(x)
          end;
        end;
      finally FileStream1.Free end;
    end;

    for i:=0 to StringList1.Count-1 do StringList1[i] := StringArr[i];
    StringList1.Insert(0, '['+Header+']');
    StringList1.SaveToFile(OutFolder+'\filelist.txt');
  finally StringList1.Free end;
end;

begin
  try
    Writeln('Prototype TBL-PAK Unpacker/Packer v1.1 by RikuKH3');
    Writeln('-------------------------------------------------');
    if ParamCount=0 then begin Writeln('Usage: '+ExtractFileName(ParamStr(0))+' <input tbl file or folder> [output tbl file or folder]'); Readln; exit end;
    if Pos('.', ExtractFileName(ParamStr(1)))=0 then PackProt else UnpackProt;
  except on E: Exception do begin Writeln(E.Message); Readln end end;
end.
