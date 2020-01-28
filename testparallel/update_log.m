function update_log(folder, user, currentJobIdentifier, priority, started_finished)

%% Check if the excel sheet that keeps the logs exists
filename = 'job_monitor.mat';

all_files = dir(folder);
filename_full = fullfile(folder,filename);

% In case this file is deleted by mistake, create it again
file_exists = ismember({all_files.name}, filename);

if ~any(file_exists)
    thestruct.User            = user;
    thestruct.Job_Identifier  = currentJobIdentifier;
    thestruct.Priority        = priority;
    thestruct.Job_Started     = '';
    thestruct.Job_Finished    = '';
else
    load(filename_full);
end



%% Add a new unique entry or append the finished time on an existing one

iEntry = find(ismember({thestruct.User}, user) & ismember({thestruct.Job_Identifier}, currentJobIdentifier) & ismember([thestruct.Priority], priority));

if ~isempty(iEntry)
    if started_finished == 1
        thestruct(iEntry).Job_Started = datestr(clock);
    elseif started_finished == 2
        thestruct(iEntry).Job_Finished = datestr(clock);
    end
else
    thestruct(end+1).User = user;
    thestruct(end).Job_Identifier = currentJobIdentifier;
    thestruct(end).Priority = priority;
    if started_finished == 1
        thestruct(end).Job_Started = datestr(clock);
    elseif started_finished == 2
        thestruct(end).Job_Finished = datestr(clock);
    end
end

%% Save .mat file
save(filename_full,'thestruct');

end
