function keep_computing = cleanup(nFiles, currentJobIdentifier, folder, user, priority)


    %% Get the files
    all_files = dir(fullfile(folder,['temp_' currentJobIdentifier]));
    allFileNames = {all_files.name};
    iAllCompletedNames = contains(allFileNames,'completed');
    
    % Unless something goes wrong, the maximum number of completed files
    % that exist in that folder should be nFiles
    
    if sum(iAllCompletedNames) == nFiles
        keep_computing = false;
        
        % Perform the cleanup
        disp('Cleaning up')
        success = rmdir(fullfile(folder,['temp_' currentJobIdentifier]),'s');
        
        if success == 1
            disp(['Succefully deleted ' currentJobIdentifier])
            try
                update_log(folder, user, currentJobIdentifier, priority, 2)
            catch
                error('Problem updating log')
            end
        else
            error(['Problem while removing ' currentJobIdentifier ' folder'])
        end
    elseif sum(iAllCompletedNames) > nFiles
        disp('Something really wrong is going on here')
        error(' ')
    end
        
end