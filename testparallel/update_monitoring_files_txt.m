function should_I_run = update_monitoring_files_txt(iFile, currentJobIdentifier, file_to_update, priority, folder)

    %% Check if other jobs with higher (smaller number) or equal priority are present and just wait for them to finish
    check_if_priority_is_highest(priority, folder, currentJobIdentifier, file_to_update); % If priority is not highest (smaller number), just wait

    %% Get the files that are already computed    
    % If folder doesn't exist, create a new one
    if ~exist(fullfile(folder,['temp_' currentJobIdentifier]), 'dir')
       mkdir(fullfile(folder,['temp_' currentJobIdentifier]))
    end
    
    all_files = dir(fullfile(folder,['temp_' currentJobIdentifier]));
    all_fileNames = {all_files.name};
    
    %% Create two different filetypes
    fileTypes = {'in_progress', 'completed'};
    
    if ismember([fileTypes{file_to_update} num2str(iFile)], all_fileNames)
        should_I_run = false;
    else
        fileName =([fullfile(folder,['temp_' currentJobIdentifier]) filesep fileTypes{file_to_update} num2str(iFile)]);
        fileID = fopen(fileName,'w');
        fwrite(fileID,1);
        fclose(fileID);
        should_I_run = true;
    end
    
    
end


function check_if_priority_is_highest(priority, folder, folder_job_specific, file_to_update)

    % Recursive function to manage job prioritization
    all_folders = dir(folder);
    all_folders = all_folders([all_folders.isdir]);
    
    % Check if other files exists with higher priority
    for iFolder = 1:length(all_folders)
        if contains(all_folders(iFolder).name, 'temp_') && ~strcmp(all_folders(iFolder).name, ['temp_' folder_job_specific]) && file_to_update == 1
            other_file_priority = split(all_folders(iFolder).name,'_');
            other_file_priority = str2double(other_file_priority{end});

            if priority > other_file_priority
                pause(5);
                disp(['I am ' folder_job_specific])
                disp(['I am waiting for ' all_folders(iFolder).name ' to finish!'])
                check_if_priority_is_highest(priority, folder, folder_job_specific)
            elseif priority == other_file_priority
                msgbox('There is already a job running with the same priority value. Change the value: 1 = High priority, >1 = lower priority','Priority value','error');
                error('There is already a job running with the same priority');
            else
                continue
            end
        end
    end
end
