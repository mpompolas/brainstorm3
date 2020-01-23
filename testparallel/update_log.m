function update_log(folder, user, script_name, priority, started_finished)
% 
% 
% 
%                  folder = [filesep fullfile('Users','Mpompolas','Desktop','testparallel')]
%                  user = 'nas'
%                  script_name = 'asdfasg'
%                  priority = 1
%                  started_finished = 1


%% Check if the excel sheet that keeps the logs exists
filename = 'job_monitor.xlsx';

all_files = dir(folder);
filename_full = fullfile(folder,filename);

% In case this file is deleted by mistake, create it again
file_exists = ismember({all_files.name}, filename);

% If not create a new one
if ~any(file_exists)
    User         = {user};
    Script_Name  = {script_name};
    Priority     = {priority};
    Job_Started  = {''};
    Job_Finished = {''};
    finalTable = table(User,Script_Name,Priority,Job_Started, Job_Finished);
    
    writetable(finalTable,filename_full,'Sheet',1,'Range','A1');
    update_log(folder, user, script_name, priority, started_finished)
end

% In case the excel is present, load its contents
keep_trying = true;

while keep_trying
    fileID = fopen(filename_full);
    if fileID ~=-1
        try
            temp = readtable(filename_full);
            fclose(fileID);
            disp('Just read from the excel')
            keep_trying = false;
        catch
        end
    else
        disp('Failed to save excel file - Retrying')
        pause(.1)
    end
end
        
thestruct = table2struct(temp);

%% Add a new unique entry or append the finished time on an existing one

iEntry = find(ismember({thestruct.User}, user) & ismember({thestruct.Script_Name}, script_name) & ismember([thestruct.Priority], priority));

if ~isempty(iEntry)
    if started_finished == 1
        thestruct(iEntry).Job_Started = datestr(clock);
    elseif started_finished == 2
        thestruct(iEntry).Job_Finished = datestr(clock);
    end
else
    thestruct(end+1).User = user;
    thestruct(end).Script_Name = script_name;
    thestruct(end).Priority = priority;
    if started_finished == 1
        thestruct(end).Job_Started = datestr(clock);
    elseif started_finished == 2
        thestruct(end).Job_Finished = datestr(clock);
    end
end

%% Save structure to excel
theCell = squeeze(struct2cell(thestruct));

User         = {theCell{1,:}}';
Script_Name  = {theCell{2,:}}';
Priority     = {theCell{3,:}}';
Job_Started  = {theCell{4,:}}';
Job_Finished = {theCell{5,:}}';

finalTable = table(User,Script_Name,Priority,Job_Started, Job_Finished);

% Save excel
keep_trying = true;
while keep_trying
    fileID = fopen(filename_full);
    if fileID ~=-1
        try
            writetable(finalTable,filename_full,'Sheet',1,'Range','A1');
            fclose(fileID);
            disp('Just wrote in the excel')
            keep_trying = false;
        catch
            fclose(fileID);
            pause(.1)
        end
    else
        pause(.1)
    end
end

end
