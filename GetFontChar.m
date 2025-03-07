function Font = GetFontChar(TargetChar, KST32Path)
%GETFONTCHAR 指定文字のKST32Bフォントを読み込む
%   詳細説明をここに記述
disp('疑問：セル配列で受け取らないとダメなようです？')
disp('バグ：数値1~を入力するとダメなようです')
disp('バグ：5文字以上はダメ見たい？')
%% ---------------------------------------------
%% フォントを読み込む文字に対応するJIS文字コード取得
%% ---------------------------------------------
% JISコードに変換（not shift-JIS）
jis_code = unicode2native(TargetChar,'JIS');
% native2unicode(jis_code,'JIS')
% JISの場合エスケープシーケンスが最初と最後の3byteづつ付与される
% 27 36 66  = ESC $ B   (JIS X 0208 に切り替え)
% 36 34     = 'あ' の JIS コード (0x2422)
% 27 40 66  = ESC ( B   (ASCII に戻す)
% どちらにせよ4文字に変換しないといけない
if length(jis_code) == 1
    jis_code = [0 jis_code];
elseif length(jis_code) > 2
    jis_code = jis_code(4:5);
end
jis_code_hex = sprintf("%02X",jis_code);

% 結果を表示
% fprintf('文字: %s のJISコード(hex表記)は: %s\n', target_char, jis_code_hex);

%% ---------------------------------------------
%% フォントデータファイルの読み込み
%% ---------------------------------------------
fileID = fopen(KST32Path, 'rb');
KST32Data = fread(fileID, 'uint8');
fclose(fileID);

% フォントの開始インデックスを探索する
% データを1バイトずつ解析
for idx_font_begin = 1 : length(KST32Data)
    code_label = string ( char(KST32Data(idx_font_begin : idx_font_begin+3))');

    % 対象のフォントを見つけるまでスキップする
    if strcmp(jis_code_hex , code_label)
        break;
    end
end

%% ---------------------------------------------
%% データの解析
%% ---------------------------------------------
lines = [];
pen_down = false;

%データ構造
%begin_x , end_x , begin_y , end_y　の4点を1行とする
begin_x=0; begin_y = 0;
end_x = []; end_y = [];

% データを1バイトずつ解析
%データ自体は6番目からのため開始のterminate:0x20を無視するために+5から進める
for i = idx_font_begin+5 : length(KST32Data)    
    % 実際のデータ読み込み
    byte = KST32Data(i);

    if byte == 0x20  % 終端記号        
        break;
    elseif (byte >= 0x21 && byte <= 0x26) || (byte >= 0x28 && byte <= 0x3F)
        % X位置を移動 X=0-29
        if byte <= 0x26 %指令位置0~5
            begin_x = byte - 0x21;
        else
            begin_x = byte - 0x28 + 6; %指令位置6~29
        end

        pen_down = false;
    elseif (byte >= 0x40 && byte <= 0x5B) || (byte >= 0x5E && byte <= 0x5F)
        % Draw to X=0-29
        if byte <= 0x5B
            end_x = byte - 0x40;
        else
            end_x = byte - 0x5E + 0x1B+1;
        end

        %ここら辺、どれを引き継ぐ座標とするのか仕様が不明瞭？
        if isempty(end_y)
            end_y = begin_y;
        end

        pen_down = true;
    elseif (byte >= 0x60 && byte <= 0x7D)
        % 次のX座標
        end_x = byte - 0x60;

        pen_down = false;
    elseif byte == 0x7E || (byte >= 0xA1 && byte <= 0xBF)
        % Move to Y=0-31
        if byte==0x7E
            begin_y = 0;
        else
            begin_y = byte - 0xA1 +1;
        end

        pen_down = false;
    elseif byte >= 0xC0 && byte <= 0xDF
        % Draw to Y=0-31
        end_y = byte - 0xC0;

        %ここら辺、どれを引き継ぐ座標とするのか仕様が不明瞭？
        if isempty(end_x)
            end_x = begin_x;
        end
        pen_down = true;
    end

    % 座標を記録
    if pen_down
        lines = [lines; begin_x,end_x , begin_y , end_y];

        begin_x = end_x;
        begin_y = end_y;

        end_x = [];
        end_y = [];
    end
end

%% ---------------------------------------------
%% 書き順補正
%% ---------------------------------------------
% 上から下>左から右の優先順位
for i=1:size(lines , 1)
    if lines(i,3) < lines(i,4)
        % 上下逆の場合->入れ替える
        lines(i,:) = [lines(i,2) , lines(i,1) ,lines(i,4) , lines(i,3)];
    elseif  lines(i,3) == lines(i,4)
        % 上下がない(横線)の場合は、左から右になるように補正する
        if lines(i,1) > lines(i,2)
            lines(i,:) = [lines(i,2) , lines(i,1) ,lines(i,4) , lines(i,3)];
        end
    end
end

% ストローク情報の初期値設定
stk_no = 1;
StrokeNo=[];
for i=1:size(lines,1)
    StrokeNo(i) = stk_no;
    % 次の線と繋がらないときはストローク違いとして自動認識する
    if i == size( lines , 1)
        ;
    elseif lines(i,2) ~= lines(i+1,1) ...
            || lines(i,4) ~= lines(i+1,3)
        stk_no = stk_no + 1;
    end
end

% Line情報の初期値設定
LineNo=1:size(lines,1);

% Line終端の初期設定
EndType = "";
for i=1:size(lines,1)
    EndType(i) = "None";
end

% 戻り値の設定
Font.Lines = double(lines);
Font.LineNo = LineNo;
Font.StrokeNo = StrokeNo;
Font.EndType = EndType;

end

