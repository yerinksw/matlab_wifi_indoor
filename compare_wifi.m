function compare_wifi(APsFile, truePositionsFile, folderPaths)
    % compare_wifi 함수: 여러 날짜의 Wi-Fi 데이터 비교 및 결과 저장

    % APs.txt 파일 읽기 (BSSID, X좌표, Y좌표)
    APs = readtable(APsFile, 'Delimiter', ',', 'ReadVariableNames', false);
    APs.Properties.VariableNames = {'BSSID', 'X', 'Y'};

    % 측점 목록 (01부터 10까지)
    measurementPoints = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10'};

    % TruePositions.txt 파일 읽기 (측점명, X좌표, Y좌표)
    truePositions = readtable(truePositionsFile, 'Delimiter', ',', 'ReadVariableNames', false);
    truePositions.Properties.VariableNames = {'PointName', 'TrueX', 'TrueY'};

    % 설정: 1미터에서의 RSSI(A), 경로 손실 지수(n)
    A = -40; % 1미터 거리에서의 신호 강도, 실험적으로 정함
    n = 4;   % 경로 손실 지수, 실내에서는 보통 2~4 (default=3)

    % 각 경로에서 날짜 추출
    dateStrs = cellfun(@(path) path(end-3:end), folderPaths, 'UniformOutput', false);

    % 각 측점에 대해 관측된 AP의 RSSI와 거리 계산
    for j = 1:length(measurementPoints)
        pointName = measurementPoints{j};

        % 현재 측점의 참값 좌표 가져오기 (TruePositions.txt의 순서에 맞게 참값 사용)
        trueX = truePositions.TrueX(j);
        trueY = truePositions.TrueY(j);

        % 각 경로에서 계산
        for k = 1:length(folderPaths)
            currentFolderPath = folderPaths{k};
            dateStr = dateStrs{k}; % 해당 경로의 날짜 추출

            wifiDataFile = fullfile(currentFolderPath, pointName, 'BSSID_Average_Strengths.csv');
            
            % 결과 저장용 테이블 초기화
            resultTable = table('Size', [0, 5], ...
                                'VariableTypes', {'string', 'double', 'double', 'double', 'double'}, ...
                                'VariableNames', {'BSSID', 'RSSI', 'Distance_Calculated', 'Distance_True', 'Expected_RSSI'});

            % 경로에서의 관측된 AP에 대한 RSSI 및 거리 계산
            if isfile(wifiDataFile)
                wifiData = readtable(wifiDataFile, 'Delimiter', ',', 'ReadVariableNames', true);

                for i = 1:height(APs)
                    bssid = APs.BSSID{i};

                    % 해당 BSSID가 관측되었는지 확인
                    idx = find(strcmp(wifiData.BSSID, bssid));
                    if ~isempty(idx)
                        % RSSI 값 가져오기
                        rssi = wifiData.AverageStrength(idx);

                        % RSSI를 통해 계산된 거리 (cm 단위)
                        distance_calculated = 100 * 10^((A - rssi) / (10 * n));

                        % 참값 좌표와 AP 좌표 간의 실제 거리 계산 (cm 단위)
                        distance_true = sqrt((trueX - APs.X(i)).^2 + (trueY - APs.Y(i)).^2);

                        % 실제 거리로부터 예상되는 RSSI 역산
                        expected_rssi = A - 10 * n * log10(distance_true / 100);

                        % 결과 테이블에 추가
                        resultTable = [resultTable; {bssid, rssi, distance_calculated, distance_true, expected_rssi}];
                    end
                end

                % 결과 파일 저장 경로
                outputFile = fullfile(currentFolderPath, pointName, [dateStr, '_', pointName, '_rssicmp.csv']);
                writetable(resultTable, outputFile);
                fprintf('파일 %s 저장 완료\n', outputFile);
            else
                fprintf('파일 %s을 찾을 수 없습니다.\n', wifiDataFile);
            end
        end
    end
end
