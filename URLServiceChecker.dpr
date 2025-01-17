program URLServiceChecker;

{$APPTYPE CONSOLE}

uses
  Winapi.WinInet,
  Winapi.Windows,
  System.SysUtils,
  Classes,
  MMSystem;

procedure LogEvent(const Msg: string);
begin
  Writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), ' - ', Msg);
end;

procedure ShowProgress(const Msg: string; Progress: Integer);
var
  i: Integer;
begin
  Write(Msg, ' [');
  for i := 1 to 50 do
  begin
    if i <= Progress div 2 then
      Write('#')
    else
      Write(' ');
  end;
  Write('] ', Progress, '%');
  Write(#13); // Move cursor back to the beginning of the line
end;

function CheckInternetConnection: Boolean;
var
  hInternet: PHINTERNET;
begin
  Result := False;
  hInternet := InternetOpen('URLChecker', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(hInternet) then
  begin
    Result := True;
    InternetCloseHandle(hInternet);
  end;
end;

function GetPageContent(const URL: string; out Content: string; out ContentSize: Int64): Boolean;
var
  hInternet: PHINTERNET;
  hConnect: PHINTERNET;
  Buffer: array[0..1023] of Byte;
  BytesRead: DWORD;
  Stream: TMemoryStream;
begin
  Result := False;
  Content := '';
  ContentSize := 0;
  hInternet := InternetOpen('URLChecker', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(hInternet) then
  try
    hConnect := InternetOpenUrl(hInternet, PChar(URL), nil, 0, INTERNET_FLAG_RELOAD, 0);
    if Assigned(hConnect) then
    try
      Stream := TMemoryStream.Create;
      try
        repeat
          if InternetReadFile(hConnect, @Buffer, SizeOf(Buffer), BytesRead) then
          begin
            if BytesRead > 0 then
              Stream.WriteBuffer(Buffer, BytesRead);
          end
          else
            Break;
        until BytesRead = 0;
        SetString(Content, PAnsiChar(Stream.Memory), Stream.Size);
        ContentSize := Stream.Size;
        Result := True;
      finally
        Stream.Free;
      end;
    finally
      InternetCloseHandle(hConnect);
    end;
  finally
    InternetCloseHandle(hInternet);
  end;
end;

procedure NotifyServiceOpened(const URL: string);
begin
  Writeln;
  LogEvent('The service at ' + URL + ' has changed.');
  PlaySound('SystemAsterisk', 0, SND_ALIAS or SND_ASYNC);
end;

var
  URL: string;
  InitialContentSize, CurrentContentSize: Int64;
  LastContent, CurrentContent: string;
  IsOpen: Boolean;
begin
  try
    Write('Enter URL: ');
    Readln(URL);

    if not CheckInternetConnection then
    begin
      LogEvent('No internet connection.');
      Exit;
    end
    else
    begin
      LogEvent('Internet connection is OK.');
    end;

    if not GetPageContent(URL, LastContent, InitialContentSize) then
    begin
      LogEvent('Failed to retrieve the initial content of the URL.');
      Exit;
    end
    else
    begin
      LogEvent('Successfully retrieved the initial content. Page size: ' + IntToStr(InitialContentSize) + ' bytes.');
    end;

    while True do
    begin
      LogEvent('Checking the service at ' + URL + '...');
      ShowProgress('Checking', 50);

      if GetPageContent(URL, CurrentContent, CurrentContentSize) then
      begin
        IsOpen := (InitialContentSize <> CurrentContentSize) or (LastContent <> CurrentContent);

        if IsOpen then
        begin
          NotifyServiceOpened(URL);
          Break;
        end
        else
          LogEvent('The service at ' + URL + ' has not changed.');

        LastContent := CurrentContent;
      end
      else
        LogEvent('Failed to retrieve the content of the URL.');

      Sleep(3000);  // Wait for 3 seconds before checking again
    end;
  except
    on E: Exception do
      LogEvent(E.ClassName + ': ' + E.Message);
  end;

  Write('Press <Enter> to exit...');
  Readln;
end.
