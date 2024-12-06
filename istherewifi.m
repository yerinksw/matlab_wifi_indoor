clc;
clear all;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% APs.txt와 측정 점의 참값이 저장된 TruePositions.txt 파일 경로
APsFile = 'APs.txt'; % AP 정보 파일
folderPath = 'C:\Users\ryn20\Desktop\설계\code\wifi1021'; % 기준 경로
date = folderPath(size(folderPath,2)-3:size(folderPath,2));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 측정한 점의 참값이 있는 파일 경로
truePositionsFile = 'TruePositions.txt'; % 참값 파일: 측점명, X좌표, Y좌표

% 날짜명 추출하여 추정 결과 파일 경로 설정
dateStr = folderPath(end-3:end); % folderPath의 마지막 4자리 숫자를 날짜명으로 사용
estimatedResultsFile = fullfile(folderPath, ['estimated_result_', dateStr, '.csv']);

% APs.txt 파일 읽기 (BSSID, X좌표, Y좌표)
APs = readtable(APsFile, 'Delimiter', ',', 'ReadVariableNames', false);

% 확인: APs.txt 파일의 열 개수에 맞게 변수 이름을 지정
if width(APs) == 3
    APs.Properties.VariableNames = {'BSSID', 'X', 'Y'};
else
    error('APs.txt 파일의 열 개수와 변수 이름의 개수가 일치하지 않습니다.');
end

% 측정한 점의 참값을 저장하는 테이블 읽기 (측점명, X좌표, Y좌표가 각 행에 있음)
truePositions = readtable(truePositionsFile, 'Delimiter', ',', 'ReadVariableNames', false, ...
    'Format', '%s%f%f'); % PointName은 string, TrueX와 TrueY는 float로 읽음 방식으로 읽음

% 확인: TruePositions.txt 파일의 열 개수에 맞게 변수 이름을 지정
if width(truePositions) == 3
    truePositions.Properties.VariableNames = {'PointName', 'TrueX', 'TrueY'};
else
    error('TruePositions.txt 파일의 열 개수와 변수 이름의 개수가 일치하지 않습니다.');
end

% 추정 결과 파일 읽기 (측점명, 추정 X좌표, 추정 Y좌표가 포함됨)
estimatedResults = readtable(estimatedResultsFile, 'Delimiter', ',', 'ReadVariableNames', true);

% 설정: 1미터에서의 RSSI(A), 경로 손실 지수(n)
A = -40;  % 1미터 거리에서의 신호 강도, 실험적으로 정함
n = 4;    % 경로 손실 지수, 실내에서는 보통 2~4 (default=3)

% 모든 측정점에 대해 개별 표 저장
for j = 1:height(truePositions)
    % 현재 측정점의 이름 및 참값 좌표
    pointName = truePositions.PointName{j};
    
    % 현재 측정점 폴더 경로
    pointFolderPath = fullfile(folderPath, pointName);

    % BSSID_Average_Strengths.csv 파일 경로
    wifiDataFile = fullfile(pointFolderPath, 'BSSID_Average_Strengths.csv');
    wifiData = readtable(wifiDataFile, 'Delimiter', ',', 'ReadVariableNames', true);

    % BSSID_STD.csv 파일 경로
    stdFilePath = fullfile(pointFolderPath, 'BSSID_STD.csv');
    bssidStdData = readtable(stdFilePath, 'Delimiter', ',', 'ReadVariableNames', true);

    % BSSID_STD 파일의 표준편차 열 이름이 'std'인지 확인하고, 다르면 수정
    if ~ismember('std', bssidStdData.Properties.VariableNames)
        error('BSSID_STD.csv 파일에 std 열이 없습니다. 열 이름을 확인해주세요.');
    end

    % AP 관측 정보 저장용 테이블 초기화 (std 열을 4번째, distance를 5번째 열로 설정)
    observedAPTable = table('Size', [12, 5], ...
                            'VariableTypes', {'string', 'double', 'double', 'double', 'double'}, ...
                            'VariableNames', {'BSSID', 'Observed', 'RSSI', 'std', 'Distance'});

    % 12개의 AP에 대한 관측 정보 채우기
    for i = 1:height(APs)
        observedAPTable.BSSID(i) = APs.BSSID(i);
        observedAPTable.Observed(i) = 0; % 기본값: 관측되지 않음
        observedAPTable.RSSI(i) = NaN;
        observedAPTable.Distance(i) = NaN;
        observedAPTable.std(i) = NaN; % 기본값: 표준편차 없음

        % 관측된 AP일 경우 RSSI 및 거리 계산
        idx = find(strcmp(wifiData.BSSID, APs.BSSID{i}));
        if ~isempty(idx)
            observedAPTable.Observed(i) = 1; % 관측됨
            observedAPTable.RSSI(i) = wifiData.AverageStrength(idx);
            % 거리 계산
            observedAPTable.Distance(i) = 10^((A - observedAPTable.RSSI(i)) / (10 * n));
            
            % 표준편차 값을 BSSID_STD 파일에서 가져와 추가
            stdIdx = find(strcmp(bssidStdData.BSSID, APs.BSSID{i}));
            if ~isempty(stdIdx)
                observedAPTable.std(i) = bssidStdData.std(stdIdx); % 표준편차 값 추가
            end
        end
    end

    % 관측 정보 테이블을 파일로 저장
    outputFileName = fullfile(pointFolderPath, [pointName, '_ObservedAP.csv']);
    writetable(observedAPTable, outputFileName);
    fprintf('파일 %s 저장 완료\n', outputFileName);

    % 현재 측정점에 대한 플롯 설정 (주석 처리)
    figure;
    hold on;
    title([date(1:2),'월 ', date(3:4), '일 관측 결과, 측점: ', pointName]);
    xlabel('X 좌표 (m)');
    ylabel('Y 좌표 (m)');
    
    % X, Y 표시 범위 및 축 비율 설정
    xlim([-15, 20]);
    ylim([0, 35]);
    axis equal; % x축과 y축 비율을 1:1로 설정

    % 모든 AP를 큰 초록색 점으로 표시
    h1 = scatter(APs.X/100, APs.Y/100, 100, 'g', 'filled'); % 모든 AP 위치 (초록색)

    % 관찰된 AP와 거리 원 플로팅
    for i = 1:height(APs)
        bssid = APs.BSSID{i};

        % 해당 BSSID의 RSSI를 wifiData에서 찾음
        idx = find(strcmp(wifiData.BSSID, bssid));

        if ~isempty(idx)
            rssi = wifiData.AverageStrength(idx); % 해당 AP의 RSSI

            % RSSI를 거리로 변환
            d = 10^((A - rssi) / (10 * n)); % AP와의 거리 계산 (m 단위)

            % 관찰된 AP를 빨간색 X로 표시하고 거리 원을 검정 실선으로 그림
            h2 = plot(APs.X(i)/100, APs.Y(i)/100, 'rx', 'MarkerSize', 8, 'LineWidth', 2); % 관찰된 AP 위치 (빨간색 X)
            viscircles([APs.X(i)/100, APs.Y(i)/100], d, 'Color', 'k', 'LineStyle', '-'); % 추정 거리 원 (검정색 실선)
        end
    end

    % 측정점의 참값을 자주색 별로 표시
    h3 = plot(truePositions.TrueX(j)/100, truePositions.TrueY(j)/100, 'm*', 'MarkerSize', 10, 'LineWidth', 2); % 측정점 참값 (자주색 별)

    % 추정된 위치를 파란색 네모로 표시
    h4 = plot(estimatedResults.EstimatedX(j)/100, estimatedResults.EstimatedY(j)/100, 'bs', 'MarkerSize', 8, 'LineWidth', 1.5, 'MarkerFaceColor','b'); % 추정 위치 (파란색 네모)

    % 추정 거리를 나타내는 검정색 원의 범례 추가를 위한 임시 플롯
    h5 = plot(NaN, NaN, 'k-', 'LineWidth', 1.5); % 검정색 실선 원

    % 범례 추가 (오른쪽 상단에 고정)
    legend([h1, h2, h3, h4, h5], {'AP', '관측된 AP', '참값', '추정값', '추정 거리'}, 'Location', 'northeast');
    hold off;

    saveas(gcf, fullfile(folderPath, ['a_plot_', pointName, '.png']));
    fprintf('파일 plot_%s.png 저장 완료\n', pointName);
end
