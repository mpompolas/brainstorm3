function keep_computing = cleanup(nFiles, currentJobIdentifier, folder)

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
        try
            rmdir(fullfile(folder,['temp_' currentJobIdentifier]),'s')
            disp(['Succefully deleted ' currentJobIdentifier])
        catch
            disp(['Problem while removing ' currentJobIdentifier ' folder'])
        end
    elseif sum(iAllCompletedNames) > nFiles
        disp('Something really wrong is going on here')
        error(' ')
    end
        
end