clc; clear all;

% 기준 경로 설정
baseFolder = 'C:\Users\ryn20\Desktop\설계\code\';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 캘리브레이션을 적용할 날짜 설정 (예: '1025' 형식)
calibrationDate = '1021';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 폴더 이름 패턴 (wifixxxx 형식의 폴더만 선택)
folderPattern = fullfile(baseFolder, 'wifi*');
folders = dir(folderPattern);

% 모든 측점에 대한 dx, dy 값을 저장할 테이블 초기화
allResults = table('Size', [0, 3], 'VariableTypes', {'string', 'double', 'double'}, ...
    'VariableNames', {'PointName', 'dX', 'dY'});

% 각 폴더를 순회하며 estimated_result_xxxx.csv 파일 읽기 (설정된 날짜 제외)
for i = 1:length(folders)
    folderName = folders(i).name;
    folderPath = fullfile(baseFolder, folderName);
    
    % 파일 이름 설정 (estimated_result_xxxx.csv)
    csvFileName = ['estimated_result_', folderName(5:end), '.csv']; % 폴더명에서 숫자 부분 추출
    csvFilePath = fullfile(folderPath, csvFileName);
    
    % 설정된 날짜에 해당하는 데이터는 평균 계산에서 제외
    if strcmp(folderName(5:end), calibrationDate)
        continue;
    end
    
    % 파일 존재 여부 확인
    if ~isfile(csvFilePath)
        fprintf('파일 %s이(가) 존재하지 않습니다.\n', csvFilePath);
        continue;
    end
    
    % CSV 파일 읽기
    resultData = readtable(csvFilePath, 'Delimiter', ',', 'ReadVariableNames', true);
    
    % 결과를 allResults 테이블에 추가
    for j = 1:height(resultData)
        pointName = resultData.PointName(j); % 소괄호 사용
        dx = resultData.dX(j);
        dy = resultData.dY(j);
        
        % 새로운 행을 테이블로 생성
        newRow = table(pointName, dx, dy, 'VariableNames', {'PointName', 'dX', 'dY'});
        
        % 기존 테이블에 새로운 행을 추가
        allResults = [allResults; newRow];
    end
end

% 각 측점별 평균 dx, dy 계산 (inf 값을 제외하고 계산)
finiteResults = allResults(isfinite(allResults.dX) & isfinite(allResults.dY), :);
averageErrors = varfun(@mean, finiteResults, 'InputVariables', {'dX', 'dY'}, ...
    'GroupingVariables', 'PointName');

% PointName을 오름차순으로 정렬 (1, 2, 3, ..., 10 순서로)
averageErrors = sortrows(averageErrors, 'PointName');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 보정 기준 설정 (200cm 이상인 경우에만 보정 적용)
calibrationThreshold = 200; % cm 단위
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 최종 보정값 계산: 위 기준 이상인 경우에만 평균 오차를 적용
averageErrors.Calibrated_dX = averageErrors.mean_dX;
averageErrors.Calibrated_dY = averageErrors.mean_dY;

% 보정 기준을 넘지 않는 경우 보정값을 0으로 설정
averageErrors.Calibrated_dX(abs(averageErrors.Calibrated_dX) < calibrationThreshold) = 0;
averageErrors.Calibrated_dY(abs(averageErrors.Calibrated_dY) < calibrationThreshold) = 0;

% 설정된 날짜의 데이터에 대해 캘리브레이션을 적용
calibrationFolderPath = fullfile(baseFolder, ['wifi', calibrationDate]);
calibrationFileName = ['estimated_result_', calibrationDate, '.csv'];
calibrationFilePath = fullfile(calibrationFolderPath, calibrationFileName);

% 설정된 날짜의 파일 존재 여부 확인
if ~isfile(calibrationFilePath)
    error('설정된 날짜의 파일 %s이(가) 존재하지 않습니다.\n', calibrationFilePath);
end

% 설정된 날짜의 CSV 파일 읽기
calibrationData = readtable(calibrationFilePath, 'Delimiter', ',', 'ReadVariableNames', true);

% 최종 결과를 저장할 테이블 초기화
finalResults = table('Size', [0, 11], 'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'PointName', 'OriginalEstimatedX', 'OriginalEstimatedY', 'TrueX', 'TrueY', 'CalibratedX', 'CalibratedY', 'dX', 'dY', 'Calibrated_dX', 'Calibrated_dY'});

% 설정된 날짜의 측점에 대해 보정값을 적용
for j = 1:height(calibrationData)
    pointName = calibrationData.PointName(j); % 소괄호 사용
    estimatedX = calibrationData.EstimatedX(j);
    estimatedY = calibrationData.EstimatedY(j);
    trueX = calibrationData.TrueX(j);
    trueY = calibrationData.TrueY(j);
    
    % 현재 측점에 대한 보정값 찾기
    idx = find(strcmp(string(averageErrors.PointName), string(pointName)));
    if isempty(idx)
        % 보정값이 없는 경우, 보정값은 0으로 설정
        calibrated_dX = 0;
        calibrated_dY = 0;
    else
        % 보정값 가져오기
        calibrated_dX = averageErrors.Calibrated_dX(idx);
        calibrated_dY = averageErrors.Calibrated_dY(idx);
    end

    % 보정값 적용
    if isfinite(calibrated_dX) % inf가 아닌 경우에만 적용
        if abs((estimatedX + calibrated_dX) - trueX) < abs((estimatedX - calibrated_dX) - trueX)
            calibratedX = estimatedX + calibrated_dX; % 더하는 방향이 오차를 줄이는 경우
        else
            calibratedX = estimatedX - calibrated_dX; % 빼는 방향이 오차를 줄이는 경우
        end
    else
        calibratedX = estimatedX; % inf인 경우 보정값을 적용하지 않음
    end

    if isfinite(calibrated_dY) % inf가 아닌 경우에만 적용
        if abs((estimatedY + calibrated_dY) - trueY) < abs((estimatedY - calibrated_dY) - trueY)
            calibratedY = estimatedY + calibrated_dY; % 더하는 방향이 오차를 줄이는 경우
        else
            calibratedY = estimatedY - calibrated_dY; % 빼는 방향이 오차를 줄이는 경우
        end
    else
        calibratedY = estimatedY; % inf인 경우 보정값을 적용하지 않음
    end

    % 보정 후의 오차 계산
    dx = abs(calibratedX - trueX);
    dy = abs(calibratedY - trueY);

    % 새로운 행을 테이블로 생성
    newResultRow = table(pointName, estimatedX, estimatedY, trueX, trueY, calibratedX, calibratedY, dx, dy, calibrated_dX, calibrated_dY, ...
                         'VariableNames', {'PointName', 'OriginalEstimatedX', 'OriginalEstimatedY', 'TrueX', 'TrueY', 'CalibratedX', 'CalibratedY', 'dX', 'dY', 'Calibrated_dX', 'Calibrated_dY'});
    
    % 보정된 결과를 최종 테이블에 추가
    finalResults = [finalResults; newResultRow];
end

% 결과 출력
fprintf('측점명\t기존 추정 위치(X)\t기존 추정 위치(Y)\t참값(X)\t참값(Y)\t보정된 위치(X)\t보정된 위치(Y)\n');
disp(finalResults);

% 보정된 결과를 파일로 저장
outputFileName = fullfile(calibrationFolderPath, ['calibrated_result_', calibrationDate, '.csv']);
writetable(finalResults, outputFileName);
fprintf('결과 파일 %s 저장 완료\n', outputFileName);

% 캘리브레이션 값을 별도의 파일로 저장
calibrationValuesFileName = fullfile(calibrationFolderPath, ['calibration_values_', calibrationDate, '.csv']);
calibrationValues = finalResults(:, {'PointName', 'Calibrated_dX', 'Calibrated_dY'});
writetable(calibrationValues, calibrationValuesFileName);
fprintf('캘리브레이션 값 파일 %s 저장 완료\n', calibrationValuesFileName);

%% 기존 위치, 참값, 캘리브레이션된 위치를 plot하는 코드

% 플롯 설정 및 화면에 맞게 크기 조정
figure;
hold on;
grid on;
axis image; % 가로세로 비율 유지

% 기존 위치 (캘리브레이션되지 않은 OriginalEstimatedX, OriginalEstimatedY) 플롯
plot(finalResults.OriginalEstimatedX, finalResults.OriginalEstimatedY, 'bo', 'DisplayName', 'Original Estimated Position');

% 참값 (TrueX, TrueY) 플롯
plot(finalResults.TrueX, finalResults.TrueY, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, 'DisplayName', 'True Position');

% 캘리브레이션된 위치 (CalibratedX, CalibratedY) 플롯
plot(finalResults.CalibratedX, finalResults.CalibratedY, 'rx', 'DisplayName', 'Calibrated Position');

% 화살표 추가
quiver(finalResults.OriginalEstimatedX, finalResults.OriginalEstimatedY, ...
       finalResults.TrueX - finalResults.OriginalEstimatedX, finalResults.TrueY - finalResults.OriginalEstimatedY, ...
       0, 'k', 'LineWidth', 1, 'MaxHeadSize', 1, 'DisplayName', 'Error Vector');

% 플롯 꾸미기
legend show;
xlabel('X Position (cm)');
ylabel('Y Position (cm)');
title(['Position Comparison: ', calibrationDate]);
axis on;
hold off;
