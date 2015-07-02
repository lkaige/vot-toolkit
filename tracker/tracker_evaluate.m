function [files, completed] = tracker_evaluate(tracker, sequence, directory, varargin)
% tracker_evaluate Evaluates a tracker on a given sequence for experiment
%
% The core function of experimental evaluation. This function can perform various 
% types of experiments or result gathering. The data is stored to the specified 
% directory.
%
% Experiment types:
% - supervised: Repeats running a tracker on a given sequence for a number of 
%   times, taking into account its potential deterministic nature and 
%   various properties of experiments.
%
% Input:
% - tracker (struct): Tracker structure.
% - sequence (struct): Sequence structure.
% - directory (string): Directory where the results are saved.
% - varargin[Type] (string): Execution context structure. This structure contains 
%   parameters of the execution.
% - varargin[Parameters] (struct): Execution parameters structure. This structure contains 
%   parameters of the execution.
% - varargin[Scan] (boolean): Do not evaluate the tracker but simply scan the directory
%   for files that are generated and return their list.
%
% Output:
% - files (cell): An array of files that were generated during the evaluation.
% - completed (boolean): Was the evaluation completed.

    scan = false;
    type = 'supervised';
    parameters = struct();
    files = {};
    completed = true;
    cache = get_global_variable('cache', 0);

    for j=1:2:length(varargin)
        switch lower(varargin{j})
            case 'parameters', parameters = varargin{j+1};
            case 'type', type = varargin{j+1};
            case 'scan', scan = varargin{j+1};
            otherwise, error(['unrecognized argument ' varargin{j}]);
        end
    end

    mkpath(directory);

    % In case of scanning we enable chaching so that results do not get re-evaluated
    if scan
        cache = true;
    end;

    switch type
    case 'supervised'

        defaults = struct('repetitions', 15, 'skip_labels', {{}}, 'skip_initialize', 0, 'failure_overlap',  -1);
        context = struct_merge(parameters, defaults);

        time_file = fullfile(directory, sprintf('%s_time.txt', sequence.name));

        times = zeros(sequence.length, context.repetitions);

        if cache && exist(time_file, 'file')
            times = csvread(time_file);
        end;

        for i = 1:context.repetitions

            result_file = fullfile(directory, sprintf('%s_%03d.txt', sequence.name, i));

            if cache && exist(result_file, 'file')
                files{end+1} = result_file; %#ok<AGROW>
                continue;
            end;

            if i == 4 && is_deterministic(sequence, 3, directory)
                print_debug('Detected a deterministic tracker, skipping remaining trials.');
                break;
            end;

            if scan
                completed = false;
                continue;
            end;

            print_indent(1);

            print_text('Repetition %d', i);

            context.repetition = i;
                    
            [trajectory, time] = tracker.run(tracker, sequence, context);        
            
            print_indent(-1);

            if numel(time) ~= sequence.length   
                times(:, i) = mean(time);
            else
                times(:, i) = time;
            end
            
            if ~isempty(trajectory)
                write_trajectory(result_file, trajectory);
		        csvwrite(time_file, times);
            end;
        end;

        if exist(time_file, 'file')
            files{end+1} = time_file;
        else
            completed = false;
        end;

    otherwise, error(['unrecognized type ' type]);

    end

end
