%% Initialization parameters

user = 'Konstantinos';
priority = 14;

%% This should be set forever - Don't change
folder = '/Users/Mpompolas/Documents/GitHub/brainstorm3/testparallel';
% folder = 'Z:\Parallel processing monitor';

%% Start of the code
JobIdentifier = [user '_' mfilename '_' num2str(priority)];

update_log(folder, user, JobIdentifier, priority, 1)

nRepetitions = 100;

parfor iFile = 1:nRepetitions%length(sFiles)
    should_I_run = update_monitoring_files_txt(iFile, JobIdentifier, 1, priority, folder);

    if should_I_run
        disp(['About to run: ' num2str(iFile)])
        a = inv(rand(1000));
        update_monitoring_files_txt(iFile, JobIdentifier, 2, priority, folder);
    end

    % ADD A CLEANUP PROCESS HERE - if everything is completed, delete the .mat files
    cleanup(nRepetitions, JobIdentifier, folder);
end
update_log(folder, user, JobIdentifier, priority, 2)




%% In case something went wrong and one of the jobs needed to be cancelled, some
% of the files started getting computed but never finished, so they need to
% be recalculated.

% emergency_function(folder, JobIdentifier);





%% If needed, convert the log from a struct to Excel
convert_log_to_excel(folder)