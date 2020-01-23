%% Initialization parameters

user = 'Konstantinos';
priority = 1;




%% This should be set forever - Don't change
folder = [filesep fullfile('Users','Mpompolas','Desktop','testparallel')];

%% Start of the code
currentJobIdentifier = [user '_' mfilename '_' num2str(priority)];

% Input files
sFiles = {...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial001_02.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial002_02.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial003_02.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial004_02.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial005.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial006.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial007.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial008.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial009.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial010.mat', ...
    'NewSubject/Maximum_force3_SGMx3/data_Maximum_force3_SGMx3_trial011.mat'};

% % Start a new report
% bst_report('Start', sFiles);


% keep_computing = true;
% 
% while keep_computing
update_log(folder, user, currentJobIdentifier, priority, 1)

    parfor iFile = 1:100%length(sFiles)
%         should_I_run = update_monitoring_files(iFile, length(sFiles), user, current_script_name, 1, priority, folder); % 1 is for updating "in_progress file"
        should_I_run = update_monitoring_files_txt(iFile, currentJobIdentifier, 1, priority, folder);
        
        if should_I_run

            disp(['About to run: ' num2str(iFile)])
            a = inv(rand(1000));

%             brainstorm server
%             % Process: Low-pass:40Hz
%             sFiles_new = bst_process('CallProcess', 'process_bandpass', sFiles{iFile}, [], ...
%                                 'sensortypes', 'MEG, EEG', ...
%                                 'highpass',    0, ...
%                                 'lowpass',     40, ...
%                                 'tranband',    0, ...
%                                 'attenuation', 'strict', ...  % 60dB
%                                 'ver',         '2019', ...  % 2019
%                                 'mirror',      0, ...
%                                 'overwrite',   0);
        end

%         update_monitoring_files(iFile, length(sFiles), user, current_script_name, 2, priority, folder);  % 2 is for updating "completed file"
        update_monitoring_files_txt(iFile, currentJobIdentifier, 2, priority, folder);

        
        % ADD A CLEANUP PROCESS HERE - if everything is completed, delete the .mat files
%         cleanup(length(sFiles), currentJobIdentifier, folder);
        cleanup(100, currentJobIdentifier, folder);
    end
    
% end
update_log(folder, user, currentJobIdentifier, priority, 2)


% Save and display report
% ReportFile = bst_report('Save', sFiles);
% bst_report('Open', ReportFile);
% bst_report('Export', ReportFile, ExportDir);

