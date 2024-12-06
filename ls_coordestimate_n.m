clc;
clear all;
close all;

% APs.txt와 측정 점의 참값이 저장된 파일 경로
APsFile = 'APs.txt'; % AP 정보 파일
truePositionsFile = 'C:\Users\ryn20\Desktop\설계\code\TruePositions.txt'; % 참값 파일

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 여러 날짜 폴더 경로 설정
% 사용자에 맞춰 폴더명 변경
folderPaths = {
    'C:\Users\ryn20\Desktop\설계\code\wifi1020'
    'C:\Users\ryn20\Desktop\설계\code\wifi1021'
    % 필요 시 더 많은 폴더 경로 추가
};
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% APs.txt 파일 읽기 (BSSID, X좌표, Y좌표)
APs = readtable(APsFile, 'Delimiter', ',', 'ReadVariableNames', false);
if width(APs) == 3
    APs.Properties.VariableNames = {'BSSID', 'X', 'Y'};
else
    error('APs.txt 파일의 열 개수와 변수 이름의 개수가 일치하지 않습니다.');
end

% 측정한 점의 참값을 저장하는 테이블 읽기 (측점명, X좌표, Y좌표가 각 행에 있음)
truePositions = readtable(truePositionsFile, 'Delimiter', ',', 'ReadVariableNames', false, ...
    'Format', '%s%f%f'); % PointName은 string, TrueX와 TrueY는 float로 읽음 방식으로 읽음
if width(truePositions) == 3
    truePositions.Properties.VariableNames = {'PointName', 'TrueX', 'TrueY'};
else
    error('TruePositions.txt 파일의 열 개수와 변수 이름의 개수가 일치하지 않습니다.');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 설정: 1미터에서의 RSSI(A), 경로 손실 지수(n)
A = -40;  % 1미터 거리에서의 신호 강도, 실험적으로 정함
n = 4;    % 경로 손실 지수, 실내에서는 보통 2~4 (default=4)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 측정점 목록 (01부터 10까지)
measurementPoints = {'11', '12'};

% 최종 결과 테이블 초기화
finalResults = table('Size', [0, 7], 'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'PointName', 'EstimatedX', 'EstimatedY', 'TrueX', 'TrueY', 'dX', 'dY'});

% 각 측점 및 날짜 폴더에 대해 데이터를 비교
for folderIdx = 1:length(folderPaths)
    folderPath = folderPaths{folderIdx};
    measurementDate = folderPath(end-3:end); % 날짜 추출

    for j = 1:height(truePositions)
        % 현재 측정점의 이름 및 참값 좌표
        pointName = truePositions.PointName{j};
        trueX = truePositions.TrueX(j);
        trueY = truePositions.TrueY(j);

        % 현재 측정점 폴더 경로
        pointFolderPath = fullfile(folderPath, pointName);
        
        % Wi-Fi 데이터 처리 및 BSSID_Average_Strengths.csv 파일 생성
        readwififile(pointFolderPath);

        % BSSID_Average_Strengths.csv 파일 경로
        wifiDataFile = fullfile(pointFolderPath, 'BSSID_Average_Strengths.csv');
        
        % Wi-Fi 데이터 파일이 있는 경우 위치 추정 수행
        if isfile(wifiDataFile)
            wifiData = readtable(wifiDataFile, 'Delimiter', ',', 'ReadVariableNames', true);
            estimatedLocations = [];

            % AP 정보를 기반으로 각 AP에 대해 위치를 추정할 데이터 구성
            for i = 1:height(APs)
                bssid = APs.BSSID{i};

                % 해당 BSSID의 RSSI를 wifiData에서 찾음
                idx = find(strcmp(wifiData.BSSID, bssid));
                if ~isempty(idx)
                    rssi = wifiData.AverageStrength(idx); % 해당 AP의 RSSI

                    % RSSI를 거리로 변환
                    d = 10^((A - rssi) / (10 * n)); % AP와의 거리 계산

                    % AP의 좌표와 거리로 최소제곱법용 데이터 구성
                    estimatedLocations = [estimatedLocations; APs.X(i), APs.Y(i), d];
                else
                    fprintf('BSSID %s에 대한 RSSI 데이터 없음.\n', bssid);
                end
            end

            % 최소제곱법을 사용하여 사용자의 위치 추정
            if size(estimatedLocations, 1) < 3
                fprintf('AP 데이터가 충분하지 않습니다. 최소 3개의 AP가 필요합니다.\n');
                finalResults = [finalResults; {pointName, NaN, NaN, trueX, trueY, NaN, NaN}];
            else
                % AP 위치(X, Y) 및 거리 데이터를 분리
                AP_positions = estimatedLocations(:, 1:2);
                distances = estimatedLocations(:, 3);

                % 최소제곱법 방정식 설정
                A_matrix = [];
                b_vector = [];
                for i = 1:length(distances)-1
                    x1 = AP_positions(i, 1);
                    y1 = AP_positions(i, 2);
                    d1 = distances(i);

                    x2 = AP_positions(i+1, 1);
                    y2 = AP_positions(i+1, 2);
                    d2 = distances(i+1);

                    % 선형화된 방정식 생성
                    A_matrix = [A_matrix; 2*(x2 - x1), 2*(y2 - y1)];
                    b_vector = [b_vector; (d1^2 - d2^2 + x2^2 - x1^2 + y2^2 - y1^2)];
                end

                % 최소제곱 해법으로 사용자 위치 추정
                estimatedPos = A_matrix \ b_vector;

                % 추정치와 참값의 차이 계산
                dx = abs(estimatedPos(1) - trueX);
                dy = abs(estimatedPos(2) - trueY);

                % 최종 결과 테이블에 추가
                finalResults = [finalResults; {pointName, estimatedPos(1), estimatedPos(2), trueX, trueY, dx, dy}];
            end
        else
            fprintf('파일 %s을 찾을 수 없습니다.\n', wifiDataFile);
        end
    end

    % 결과 파일 저장 경로
    outputFileName = fullfile(folderPath, ['estimated_result_', measurementDate, '.csv']);
    writetable(finalResults, outputFileName);
    fprintf('결과 파일 %s 저장 완료\n', outputFileName);
end

% compare_wifi 함수 호출
compare_wifi(APsFile, truePositionsFile, folderPaths);
