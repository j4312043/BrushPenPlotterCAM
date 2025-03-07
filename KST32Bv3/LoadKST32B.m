%% KST32BをMATLABで扱えるように読み込む
% [1]https://shikarunochi.matrix.jp/?p=4276
format compact;
close all;clear all;

%% ---------------
%% 表示文字に対応するJIS文字コード取得
%% ---------------
% 読み込みたい文字を定義
% target_char = 'あ';
% target_char = 'A';
% target_char = '佐';
% target_char = '藤';
% target_char = '郁';
target_char = '弥';

% JISコードに変換（not shift-JIS）
jis_code = unicode2native(target_char,'JIS');
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
fprintf('文字: %s のJISコード(hex表記)は: %s\n', target_char, jis_code_hex);

%% ---------------
%% フォントデータの読み込み
%% ---------------
% バイナリファイルを開く
fileID = fopen('KST32B.TXT', 'rb');
rawData = fread(fileID, 'uint8');
fclose(fileID);

for i=1:length(rawData)
    code_label = string ( char(rawData(i:i+3))');
    
    if strcmp(jis_code_hex , code_label)
        disp(['読み込むフォントの文字コード(JIS)',code_label]);
        break;
    end
end
FontData = rawData(i:i+200);
disp('読み込む量は適当に決め打ち中');

disp("対象フォントデータ(bin)");
sprintf("%02x", FontData)

%% ---------------
%% データの解析
%% ---------------
points = [];
pen_down = false;

%データ構造
%begin_x , begin_y , end_x , end_y　の4点を１つのLINEとする
begin_x=0; begin_y = 0;
end_x = []; end_y = [];
% end_x = 0 ; end_y = 0;

% データを1バイトずつ解析
for i = 6:length(FontData) %データ自体は6番目から(0x20を探してその次の文字からでもOK)
    byte = FontData(i);

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
        points = [points; begin_x,end_x , begin_y , end_y];

        begin_x = end_x;
        begin_y = end_y;  
       
        end_x = [];
        end_y = [];
    end
end


%% ---------------
%% フォント描画
%% ---------------
figure;
hold on;
for i = 1:size(points,1)
    plot(points(i,1:2), points(i,3:4), 'k-', 'LineWidth', 2);

    % pause;
end
axis equal;
xlim([0 29]);  ylim([0,31]);
title('KST32B Font');
hold off;
