%% Initialization parameters

user = 'Konstantinos';
priority = 1;

%% This should be set forever - Don't change
folder = '/Users/Mpompolas/Documents/GitHub/brainstorm3/testparallel';
% folder = 'Z:\Parallel processing monitor';

%% Start of the code
currentJobIdentifier = [user '_' mfilename '_' num2str(priority)];

% update_log(folder, user, currentJobIdentifier, priority, 1)

for iFile = 1:100%length(sFiles)
    should_I_run = update_monitoring_files_txt(iFile, currentJobIdentifier, 1, priority, folder);

    if should_I_run
        disp(['About to run: ' num2str(iFile)])
        a = inv(rand(1000));
        update_monitoring_files_txt(iFile, currentJobIdentifier, 2, priority, folder);
    end

    % ADD A CLEANUP PROCESS HERE - if everything is completed, delete the .mat files
    cleanup(100, currentJobIdentifier, folder);
end
% update_log(folder, user, currentJobIdentifier, priority, 2)
