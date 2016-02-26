function [ data ] = loadData( data )
%LOADDATA Summary of this function goes here
%   Detailed explanation goes here

sgolay_K = num2str(3);
sgolay_F = num2str(57);

% length(data.parts) is the lists (parts, labels, ndof) length in 'data'
% structure. list length = number of sensors (ex: 11 acc + "leg_position").
% For instance, for the leg, q_1 to q_6 are seen like a single sensor of 6
% dof ("leg_position"), and that's the way it is read from stateExt:o.

% Create function handles for assigning variables :
%   q_<labels{i}>, dq_<labels{i}>, d2q_<labels{i}>
%   qs_<labels{i}>, dqs_<labels{i}>, d2qs_<labels{i}>
%   qsRad_<labels{i}>, dqsRad_<labels{i}>, d2qsRad_<labels{i}>
%   y_<labels{i}>
%   ys_<labels{i}>

% meas = {};
% 
% for i = 1 : length(data.parts)
%     
%     eval(['meas{i}.t = @(x) data.t_' data.labels{i} ' = x;']);
%     
%     if strcmp(data.type{i}, 'stateExt:o');
%         eval(['meas{i}.q = @(x) data.q_' data.labels{i} ' = x;']);
%         eval(['meas{i}.dq = @(x) data.dq_' data.labels{i} ' = x;']);
%         eval(['meas{i}.d2q = @(x) data.d2q_' data.labels{i} ' = x;']);
% 
%         eval(['meas{i}.qs = @(x) data.qs_' data.labels{i} ' = x;']);
%         eval(['meas{i}.dqs = @(x) data.dqs_' data.labels{i} ' = x;']);
%         eval(['meas{i}.d2qs = @(x) data.d2qs_' data.labels{i} ' = x;']);
% 
%         eval(['meas{i}.qsRad = @(x) data.qsRad_' data.labels{i} ' = x;']);
%         eval(['meas{i}.dqsRad = @(x) data.dqsRad_' data.labels{i} ' = x;']);
%         eval(['meas{i}.d2qsRad = @(x) data.d2qsRad_' data.labels{i} ' = x;']);
%    else
%         eval(['meas{i}.y = @(x) data.y_' data.labels{i} ' = x;']);
%         eval(['meas{i}.ys = @(x) data.ys_' data.labels{i} ' = x;']);
%    end
% end

% init buffers
qBuff = []; dqBuff = []; d2qBuff = []; tStateBuff = [];
for i = 1 : length(data.parts)
    bufferId = ['buffer_' data.parts{i} '_' data.type{i}(1:end-2)];
    eval(['readFile_' bufferId ' = []']);
end

% Load data from dump files
for i = 1 : length(data.parts)
    file = [data.path data.parts{i} '/' data.type{i} '/data.log'];
    % this buffer Id avoids reading the same file twice
    bufferId = ['buffer_' data.parts{i} '_' data.type{i}(1:end-2)];
    
    if strcmp(data.type{i}, 'stateExt:o');
        q    = ['q_' data.labels{i}];
        dq   = ['dq_' data.labels{i}];
        d2q  = ['d2q_' data.labels{i}];
        t    = ['time_' data.labels{i}];
        % trigger and register the unique read of the file
        eval(['readFile_' bufferId ' = isempty(readFile_' bufferId ');']);
        eval(['readFile = readFile_' bufferId]);
        % Read file.
        if readFile
            [qBuff,dqBuff,d2qBuff,tStateBuff] = readStateExt(data.ndof{i},file);
        end
        % Parse file content.
        % (dynamicaly create new fields of "data")
        eval(['data.' t ' = tStateBuff;']);
        eval(['data.'  q  '= qBuff(' data.index{i} ',:);']);
        eval(['data.' dq  '= dqBuff(' data.index{i} ',:);']);
        eval(['data.' d2q '= d2qBuff(' data.index{i} ',:);']);
        
        if data.diff_q
            eval(['data.'   q '(:, :   )= sgolayfilt(data.'   q ''',' sgolay_K ',' sgolay_F ')'' ;'])
            eval(['data.'  dq '(:,2:end)= 1/mean(diff(data.' t ')).*diff(data.'  q ''')'' ;'])
            eval(['data.'   dq '(:, :   )= sgolayfilt(data.'   dq ''',' sgolay_K ',' sgolay_F ')'' ;'])
            eval(['data.' d2q '(:,2:end)= 1/mean(diff(data.' t ')).*diff(data.' dq ''')'' ;'])
        end
        
    else
        y    = ['y_' data.labels{i}];
        t    = ['time_' data.labels{i}];
        % trigger and register the unique read of the file
        eval(['readFile_' bufferId ' = isempty(readFile_' bufferId ');']);
        eval(['readFile = readFile_' bufferId]);
        % Read file.
        if readFile
            [yBuff,tAccBuff] = readDataDumper(file);
        end
        % Parse file content.
        fprintf('Loaded sensor %s\n',data.labels{i})
        eval(['data.' t ' = tAccBuff;']);
        eval(['data.' y '= yBuff(:,' data.index{i} ');']);
        
        
        if(strcmp(y(end-2:end), 'imu') && data.diff_imu)
            eval(['data.' y '(2:end,4:6)= 1/mean(diff(data.' t ')).*diff(sgolayfilt(data.' y '(:,4:6),' sgolay_K ',' sgolay_F '));'])
        end
        eval(['data.' t '=data.' t ''';']);
        eval(['data.' y '=data.' y ''';']);
        
        % add filtering
        eval(['data.' y '=sgolayfilt(data.' y ''',' sgolay_K ',' sgolay_F ')'';']);
        
    end
end

min_times = [];
max_times = [];
for i = 1 : length(data.labels)
   max_time  = ['max_time_', data.labels{i}];
   min_time  = ['min_time_', data.labels{i}];
   t         = ['data.time_' data.labels{i}];
   eval([max_time ' = max(' t ');']);
   eval([min_time ' = min(' t ');']);
   
   min_times = [min_times eval(min_time)];
   max_times = [max_times eval(max_time)];
end

time_i = max(min_times);
time_f = min(max_times);

for i = 1 : length(data.labels)
   tf  = eval(['max_time_', data.labels{i}]);
   ti  = eval(['min_time_', data.labels{i}]);
   
   if abs(tf - time_f) > 1 || abs(ti - time_i) > 1
      fprintf(['[WARNING] There is some lag in the ' data.parts{i} ' data: %f, %f\n'], abs(tf - time_f) ,abs(ti - time_i))
   end
   
end

time   = linspace(time_i+data.ini, time_i+data.end, data.nsamples);

%%
close all

dtime   = time(1);
for i = 1 : length(data.parts)
   
   if strcmp(data.type{i}, 'stateExt:o');
      q    = ['data.q_' data.labels{i}];
      dq   = ['data.dq_' data.labels{i}];
      d2q  = ['data.d2q_' data.labels{i}];
      t    = ['data.time_' data.labels{i}];
      
      qs   = ['qs_' data.labels{i}];
      dqs  = ['dqs_' data.labels{i}];
      d2qs = ['d2qs_' data.labels{i}];
      
      % [qs_la, dqs_la, d2qs_la] = resampleState(time, time_la, q_la, dq_la, d2q_la);
      eval(['[data.' qs ', data.' dqs ', data.' d2qs '] = resampleState(time,' t ',' q ',' dq ',' d2q ');']);
   else
      y    = ['data.y_'  data.labels{i}];
      t    = ['data.time_' data.labels{i}];
      ys   = ['ys_' data.labels{i}];
      eval(['data.' ys ' = interp1(' t ',' y ''', time)'';']);
   end
   % time_h  = time_h  - dtime;
   eval([t '=' t '- dtime;']);
end
data.time = time    - dtime;

for i = 1 : length(data.parts)
   if data.visualize{i} && strcmp(data.type{i}, 'stateExt:o')
      q    = ['data.q_' data.labels{i}];
      dq   = ['data.dq_' data.labels{i}];
      d2q  = ['data.d2q_' data.labels{i}];
      t    = ['data.time_' data.labels{i}];
      
      qs   = ['qs_' data.labels{i}];
      dqs  = ['dqs_' data.labels{i}];
      d2qs = ['d2qs_' data.labels{i}];
      
      figure
      subplot(311)
      eval(['plot(' t ',' q ')'])
      hold on
      eval(['plot(data.time,data.' qs ', ''--'' )' ]);
      title([' q_{' data.labels{i} '}'])
      subplot(312)
      eval(['plot(' t ',' dq ')'])
      hold on
      eval(['plot(data.time,data.' dqs ', ''--'' )' ]);
      title(['dq_{' data.labels{i} '}'])
      subplot(313)
      eval(['plot(' t ',' d2q ')'])
      hold on
      eval(['plot(data.time,data.' d2qs ', ''--'' )' ]);
      title(['d2q_{' data.labels{i} '}'])
   elseif data.visualize{i}
      y    = ['data.y_'  data.labels{i}];
      t    = ['data.time_' data.labels{i}];
      ys   = ['ys_' data.labels{i}];
      
      figure
      J = data.ndof{i};
      for j = 1 : J/3
         subplot([num2str(J/3) '1' num2str(j)])
         I = 1+(j-1)*3 : 3*j;
         eval(['plot(' t ',' y '(I,:))'])
         hold on
         eval(['plot(data.time,data.' ys '(I,:), ''--'' )' ]);
         title(['y_{' data.labels{i} '}'])
      end
   end
end


%% Process raw sensor data
acc_gain = 5.9855e-04;
%acc_gain = 1.0;
deg_to_rad = pi/180.0;
gyro_gain = deg_to_rad*7.6274e-03;
for i = 1 : length(data.parts)
    t    = ['time_' data.labels{i}];
    ys   = ['ys_' data.labels{i}];
    if( strcmp(data.labels{i},'lh_imu') || ...
            strcmp(data.labels{i},'rh_imu') )
        eval(['data.' ys '(1:3,:) = ' ...
            'acc_gain*data.' ys '(1:3,:);']);
        eval(['data.' ys '(4:6,:) = ' ...
            'gyro_gain*data.' ys '(4:6,:);']);
    end
    if( strcmp(data.labels{i},'imu') )
        eval(['data.' ys '(4:6,:) = ' ...
            'deg_to_rad*data.' ys '(4:6,:);']);
    end
    if( strcmp(data.labels{i}(end-2:end),'acc') )
        eval(['data.' ys '(1:3,:) = ' ...
            'acc_gain*data.' ys '(1:3,:);']);        
    end
end

fprintf('Processed raw sensors\n')


%%
% Convert qs_xxx, dqs_xxx, d2qs_xxx variables from degrees to radians
%
% % Convert qs_xxx, dqs_xxx, d2qs_xxx variables from degrees to radians
% for i = 1 : length(data.parts)
%     if strcmp(data.type{i}, 'stateExt:o');
%         meas{i}.qsRad([data.qs_rleg].*pi/180);
%         meas{i}.dqsRad([data.dqs_rleg].*pi/180);
%         meas{i}.d2qsRad([data.d2qs_rleg].*pi/180);
%     end
% end
%
% data.q - meas{12}.qsRad_rleg
% data.dq - meas{12}.dqsRad_rleg
% data.d2q - meas{12}.d2qsRad_rleg


for i = 1 : length(data.parts)
    if strcmp(data.type{i}, 'stateExt:o');
        qs    = ['qs_' data.labels{i}];
        dqs   = ['dqs_' data.labels{i}];
        d2qs  = ['d2qs_' data.labels{i}];
        
        qsRad    = ['qsRad_' data.labels{i}];
        dqsRad   = ['dqsRad_' data.labels{i}];
        d2qsRad  = ['d2qsRad_' data.labels{i}];
        
        eval(['data.' qsRad ' = data.' qs '*pi/180;']);
        eval(['data.' dqsRad ' = data.' dqs '*pi/180;']);
        eval(['data.' d2qsRad ' = data.' d2qs '*pi/180;']);
    end
end



end