function GenerateNCProgram(fullFile , RenderingText , RenderingFonts , Scale)
%GENERATENCPROGRAM この関数の概要をここに記述
%   詳細説明をここに記述
%% NCコード生成設定
% (Z=0を紙とペンが接触する位置とする)
disp('(ToDo)GenerateNCProgram内で生成条件をハードコーディング中');
SafeZ = 2; % Z方向退避座標
PlotZ = -1; % Z方向書き込み字座標
PlotFeed = 500;

%% ---------------
%% フォント位置をずらす(文字ごとに1文字文ずつ位置をずらす)
%% ---------------
for i = 1:length(RenderingFonts)
    RenderingFonts{i}.Lines = ...
        RenderingFonts{i}.Lines.*Scale - [0 ,0 , 29 , 29].*(i- length(RenderingText) ).*Scale;
end

% %% ---------------
% %% 全体描画(debug用)
% %% ---------------
% figure;
% hold on;
% for k = 1:length(RenderingFonts)
%     for i = 1:size(RenderingFonts{k}.Lines,1)
%         % plot(RenderingFonts(k).points(i,1:2) , RenderingFonts(k).points(i,3:4), 'k-', 'LineWidth', 2);
% 
%         % 矢印付きプロット
%         quiver(RenderingFonts{k}.Lines(i,1) , RenderingFonts{k}.Lines(i,3),...
%             RenderingFonts{k}.Lines(i,2) -RenderingFonts{k}.Lines(i,1) , ...
%             RenderingFonts{k}.Lines(i,4 )- RenderingFonts{k}.Lines(i,3));
%     end
% end
% 
% axis equal;
% % xlim([0 29*length(RenderingFonts)]);  ylim([0,31]);
% xlim([0 29]);  ylim([0,31*length(RenderingFonts)]);
% title('予想される描画');
% xlabel('x-axis'); ylabel('y-axis');
% hold off;

%% ---------------
%% NCコード生成
%% ---------------
% 方針：
% ・フォントのnライン目について、nライン目の終点とn+1ライン目の始点が同じ場合は、
% 　継続する線とみなしてZ方向に退避しない
% NCコード 1行に1命令(ex.G0X0Y0)を保存する
NCCodes = "%ペンプロッタコード";

% (原点に移動する)
NCCodes(end+1) = sprintf("G0Z%d",SafeZ);
NCCodes(end+1) = "G0X0Y0";

%(フォントに対応する経路を生成する)
for idx_char = 1:length(RenderingFonts)
    Font = RenderingFonts{idx_char};

    for idx_stk = unique(Font.StrokeNo)
        idx_line = Font.LineNo(Font.StrokeNo == idx_stk);

        % 最終Lineだけはトメ・ハネ・ハライに応じて変更する
        for i=1:length(idx_line)-1
            % 始点に移動
            NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                Font.Lines(idx_line(i),1) , Font.Lines(idx_line(i),3),...
                PlotFeed);
            % ペン下す(同一zなら何回下げても変わらないので1行無駄になるけど可読性重視)
            NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ,200);

            % % ストローク先頭は押しつけひき戻しする->効果なし
            % if i==1
            %     NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ*1.2,200);
            %     NCCodes(end+1) = sprintf("G4P1");
            %     NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ,200);
            %     NCCodes(end+1) = sprintf("G4P1");
            % end

            % 次の点に移動(描画)
            NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                Font.Lines(idx_line(i),2) , Font.Lines(idx_line(i),4) ,...
                PlotFeed);
        end

        % ストローク内の最終Line+(ペン上げる)
        i=length(idx_line);
        switch (Font.EndType(idx_line(end)))
            case "Tome"
                % 始点に移動
                NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                    Font.Lines(idx_line(i),1) , Font.Lines(idx_line(i),3),...
                    PlotFeed);
                % ペン下す(同一zなら何回下げても変わらないので1行無駄になるけど可読性重視)
                NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ,200);
                % 次の点に移動(描画)
                NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                    Font.Lines(idx_line(i),2) , Font.Lines(idx_line(i),4) ,...
                    PlotFeed);

                % NCCodes(end+1) = sprintf("G4P1");
                NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ*1.4,PlotFeed/4);
                % NCCodes(end+1) = sprintf("G4P1");
                NCCodes(end+1) = sprintf("G0Z%f",SafeZ);
            case "Hane"
                NCCodes(end+1) = sprintf("G1X%f Y%f Z%f F%f",...
                    Font.Lines(idx_line(i),2) , Font.Lines(idx_line(i),4) , SafeZ , ...
                    PlotFeed);

                NCCodes(end+1) = sprintf("G0Z%f",SafeZ);
            case "Harai"
                % 始点に移動
                NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                    Font.Lines(idx_line(i),1) , Font.Lines(idx_line(i),3),...
                    PlotFeed);
                % ペン下す(同一zなら何回下げても変わらないので1行無駄になるけど可読性重視)
                NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ,200);                

                % ラストストロークがsafeZとなるように放物線で上げるようにする
                plot_vector = [Font.Lines(idx_line(i),2)-Font.Lines(idx_line(i),1) , ...
                    Font.Lines(idx_line(i),4)-Font.Lines(idx_line(i),3)];
                plot_vector = plot_vector .* 1;
                HaraiStart = [Font.Lines(idx_line(i),1), Font.Lines(idx_line(i),3)];

                HaraiDistance = norm(plot_vector); %ハライの距離(これはベクトルの向きに寄らず>0になることに注意)
                
                DivPoints = 10;
                HaraiL = linspace(0,HaraiDistance , DivPoints);
                % alpha = (SafeZ-PlotZ) / HaraiDistance^2;                
                alpha = (0-PlotZ) / HaraiDistance^2;

                for i=1:DivPoints
                    NCCodes(end+1) = sprintf("G1X%fY%fZ%f F%f", ...
                        HaraiStart(1) + (plot_vector(1)/DivPoints)*i,...
                        HaraiStart(2) + (plot_vector(2)/DivPoints)*i , ...
                        PlotZ+alpha*HaraiL(i)^2 , PlotFeed);
                end

                NCCodes(end+1) = sprintf("G0Z%f",SafeZ);
            otherwise 
                % 始点に移動
                NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                    Font.Lines(idx_line(i),1) , Font.Lines(idx_line(i),3),...
                    PlotFeed);
                % ペン下す(同一zなら何回下げても変わらないので1行無駄になるけど可読性重視)
                NCCodes(end+1) = sprintf("G1Z%f F%f",PlotZ,200);
                % 次の点に移動(描画)
                NCCodes(end+1) = sprintf("G1X%f Y%f F%f",...
                    Font.Lines(idx_line(i),2) , Font.Lines(idx_line(i),4) ,...
                    PlotFeed);

                NCCodes(end+1) = sprintf("G0Z%f",SafeZ);
        end        
    end
end

%(原点に戻る)
NCCodes(end+1) = sprintf("G0Z%d",SafeZ);
NCCodes(end+1) = "G0X0Y0";

%% ---------------
%% NCコードファイル書き出し
%% ---------------
NCfileID = fopen(fullFile,'w');
fprintf(NCfileID , '%s\n',NCCodes);
fclose(NCfileID);

end

