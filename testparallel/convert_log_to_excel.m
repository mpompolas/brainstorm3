function convert_log_to_excel(folder)

%% Check if the excel sheet that keeps the logs exists
filename = 'job_monitor';

all_files = dir(folder);
filename_full = fullfile(folder,[filename '.mat']);

% In case this file is deleted by mistake, create it again
file_exists = ismember({all_files.name}, [filename '.mat']);

% If not create a new one
if ~any(file_exists)
    error('No log present!')
else
    load(filename_full);
end

        


%% Save structure to excel
theCell = squeeze(struct2cell(thestruct));

User           = {theCell{1,:}}';
Job_Identifier = {theCell{2,:}}';
Priority       = {theCell{3,:}}';
Job_Started    = {theCell{4,:}}';
Job_Finished   = {theCell{5,:}}';

finalTable = table(User,Job_Identifier,Priority,Job_Started, Job_Finished);

% Save excel
writetable(finalTable,[filename '.xlsx'],'Sheet',1,'Range','A1');

end
