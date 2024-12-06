function readwififile(folderPath)
    % readwififile 함수: 주어진 폴더 경로에서 Wi-Fi 데이터를 읽고 BSSID별로 평균 Strength와 표준편차를 계산
    % folderPath: Wi-Fi 데이터 txt 파일이 저장된 폴더 경로

    % 모든 .txt 파일 목록 가져오기
    filePattern = fullfile(folderPath, '*.txt'); % .txt 파일 패턴
    txtFiles = dir(filePattern); % 폴더에서 .txt 파일 목록 가져오기

    % BSSID별로 Strength 값을 저장할 테이블 생성 (BSSID, Strength 리스트)
    BSSID_data = containers.Map(); % BSSID를 키로 하고, RSSI 값 리스트를 값으로 저장

    % 기존 기능: BSSID별로 Strength의 합과 데이터 개수 계산
    BSSID_sum_data = containers.Map();

    % 모든 파일 읽기
    for k = 1:length(txtFiles)
        baseFileName = txtFiles(k).name;
        fullFileName = fullfile(folderPath, baseFileName);

        % 파일 읽기 (첫 줄은 헤더로 사용)
        opts = detectImportOptions(fullFileName, 'Delimiter', ',');  
        opts.VariableNames = {'SSID', 'BSSID', 'RSSI', 'Frequency', 'Capabilities', 'ChannelWidth', 'CenterFreq0', 'CenterFreq1', 'Timestamp'};  
        opts.SelectedVariableNames = {'BSSID', 'RSSI'};  
        fileData = readtable(fullFileName, opts);  

        % BSSID와 RSSI (dBm) 열 추출
        BSSIDs = fileData.BSSID;  
        Strengths = fileData.RSSI;

        % RSSI 값에서 dBm 제거 및 숫자로 변환
        for i = 1:height(fileData)
            strengthStr = Strengths{i};
            strengthNum = regexp(strengthStr, '(-?\d+)', 'match');
            if isempty(strengthNum)
                fprintf('Strength 값에서 숫자를 추출하지 못함: %s\n', strengthStr);
                continue;
            end

            strength = str2double(strengthNum{1});
            if isnan(strength)
                fprintf('BSSID: %s의 Strength 값이 NaN, 건너뜀\n', BSSIDs{i});
                continue;
            end

            bssid = BSSIDs{i};

            % 기존 BSSID가 있으면 리스트에 추가, 없으면 새로 추가
            if isKey(BSSID_data, bssid)
                BSSID_data(bssid) = [BSSID_data(bssid), strength];
            else
                BSSID_data(bssid) = [strength];
            end

            % 기존 기능: BSSID별로 Strength의 합과 개수 업데이트
            if isKey(BSSID_sum_data, bssid)
                prevData = BSSID_sum_data(bssid);
                BSSID_sum_data(bssid) = [prevData(1) + strength, prevData(2) + 1];
            else
                BSSID_sum_data(bssid) = [strength, 1];
            end
        end
    end

    % 기존 기능: BSSID별로 Strength의 평균값 계산 및 저장
    BSSIDs_sum = keys(BSSID_sum_data);
    if isempty(BSSIDs_sum)
        disp('BSSID 데이터가 없음');
    else
        averageStrengths = zeros(length(BSSIDs_sum), 1);
        for i = 1:length(BSSIDs_sum)
            bssid = BSSIDs_sum{i};
            data = BSSID_sum_data(bssid);
            strengthSum = data(1);
            count = data(2);
            averageStrengths(i) = strengthSum / count; % Strength 평균 계산
        end

        % 결과 출력 및 파일 저장
        resultTable = table(BSSIDs_sum', averageStrengths, 'VariableNames', {'BSSID', 'AverageStrength'});
        disp(resultTable);
        outputFileName = fullfile(folderPath, 'BSSID_Average_Strengths.csv');
        writetable(resultTable, outputFileName);
        fprintf('결과 파일 %s 저장 완료\n', outputFileName);
    end

    % 추가 기능: BSSID별 RSSI의 평균과 표준편차 계산 및 저장
    BSSIDs = keys(BSSID_data);
    if isempty(BSSIDs)
        disp('BSSID 데이터가 없음');
    else
        averageStrengths = zeros(length(BSSIDs), 1);
        stdDeviations = zeros(length(BSSIDs), 1);

        for i = 1:length(BSSIDs)
            bssid = BSSIDs{i};
            data = BSSID_data(bssid);
            averageStrengths(i) = mean(data); % Strength 평균 계산
            stdDeviations(i) = std(data); % Strength 표준편차 계산
        end

        % 표준편차 결과 파일 저장
        stdResultTable = table(BSSIDs', averageStrengths, stdDeviations, 'VariableNames', {'BSSID', 'AverageStrength', 'std'});
        disp(stdResultTable);
        stdOutputFileName = fullfile(folderPath, 'BSSID_STD.csv');
        writetable(stdResultTable, stdOutputFileName);
        fprintf('표준편차 결과 파일 %s 저장 완료\n', stdOutputFileName);
    end
end
