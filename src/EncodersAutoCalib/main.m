clear
close all
clc

%% define the sensor codes and links they are attached to
%
mtbSensorCodes =  {'11b1','11b2', ...
    '11b3','11b4', ...
    '11b5', ...
    '11b6', '11b7', ...
    '11b8', '11b9', ...
    '11b10','11b11'};

mtbSensorLink = {'r_upper_leg','r_upper_leg', ...
    'r_upper_leg','r_upper_leg', ...
    'r_upper_leg',               ...
    'r_upper_leg','r_upper_leg', ...
    'r_lower_leg','r_lower_leg', ...
    'r_lower_leg','r_lower_leg'};

%% define the joints to calibrate
jointsToCalibrate_right_leg = {'r_hip_pitch','r_hip_roll','r_hip_yaw','r_knee','r_ankle_pitch','r_ankle_roll'};
jointsInitOffsets_right_leg = [0 0 0 0 0 0];

% Bind the lists: common index is the part index.
jointsToCalibrate.parts = {'right_leg'};
jointsToCalibrate.joints = {jointsToCalibrate_right_leg};
jointsToCalibrate.jointsInitOffsets = {jointsInitOffsets_right_leg};


%% define offsets for parsing Linear Acceleration data from MTB accelerometers
%
% | size  |   1   |   1       |   6  |            6           | ...
% | offset|   1   |   2       | 3..8 |2+6*(i-1)+1..2+6*(i-1)+6| ...
% | Field | index | timestamp |wx..az|wx |wy |wz |ax |ay |az  | ...
%
HEADER_LENGTH = 2;
FULL_ACC_SIZE = 6;
LIN_ACC_1RST_IDX = 4;
LIN_ACC_LAST_IDX = 6;

%% generate indices and labels for the mtb sensors (Accelerometers)
%
nrOfMTBAccs = length(mtbSensorLink);
mtbIndices = {};
for i = 1:nrOfMTBAccs
    % Indexes for linear acceleration
    mtbIndices{i} = strcat(num2str(HEADER_LENGTH+FULL_ACC_SIZE*(i-1)+LIN_ACC_1RST_IDX), ...
        ':', ...
        num2str(HEADER_LENGTH+FULL_ACC_SIZE*(i-1)+LIN_ACC_LAST_IDX));
end

mtbSensorFrames = {};
for i = 1:nrOfMTBAccs
    % there is no naming convention yet. ex of sensor frame:
    % [r_upper_leg_mtb_acc_11b3]
    mtbSensorFrames{i} = strcat(mtbSensorLink{i},'_mtb_acc_',mtbSensorCodes{i});
end

mtbSensorLabel = {};
for i = 1:nrOfMTBAccs
    % ex of sensor label:
    % [11b3_acc]
    mtbSensorLabel{i} = strcat(mtbSensorCodes{i},'_acc');
end


% some sensor are inverted in the model with respect to how are mounted on
% the real robot
mtbInvertedFrames   =  {true,true, ...
    true,true, ...
    true, ...
    false,false, ...
    true,true,   ...
    true,true,   ...
    false,false};




%% Parsing configuration
%
% the fields of "data" are created here on the fly.
%
data.nsamples  = 1000; %number of samples
data.plot      = 0;
data.ini       = 2;    %seconds to be skipped at the start
data.end       = 28;   %seconds to reach the end of the movement
data.diff_imu  = 0;    %derivate the angular velocity of the IMUs
data.diff_q    = 0;    %derivate the angular velocity of the IMUs


%% strucutre from files
data.path        = '../../data/calibration/dumperExample/iCubGenova02/';
data.parts       = {};
data.labels      = {};
data.frames      = {};
data.ndof        = {};
data.index       = {};
data.type        = {};
data.visualize   = {};

%% strucutre for urdf
sens.parts       = {};
sens.labels      = {};
sens.ndof        = {};
sens.type        = {};
sens.transform  = {};

%% add mtb sensors
for i = 1:nrOfMTBAccs
    % ex of sensor drake label:
    % drake_r_upper_leg_X_urdf_r_upper_leg_acc_mtb_11B3]
    sensorTransformName = strcat('drake_', mtbSensorLink{i},'_X_urdf_',mtbSensorFrames{i});
    data = addSensToData(data, 'right_leg'    , mtbSensorFrames{i}, mtbSensorLabel{i}  , 3, mtbIndices{i}, 'inertialMTB', 1*data.plot);
end

%% add joint measurements
data = addSensToData(data, 'right_leg', '', 'rleg'      , 6, '1:6', 'stateExt:o' , 1*data.plot);

data = loadData(data);


%% plot results
label_to_plot = [mtbSensorLabel,{'11b1_acc' '11b2_acc' '11b3_acc' '11b4_acc' '11b5_acc' '11b6_acc' '11b7_acc'...
                                 '11b8_acc' '11b9_acc' '11b10_acc' '11b11_acc'...
                                 'rleg'}];

% %% Plots
% py = [0; cumsum(cell2mat(myMAP.IDsens.sensorsParams.sizes))];
% for l = 1 : length(label_to_plot)
%     for k = 1 : myMAP.IDsens.sensorsParams.ny
%         if strcmp(myMAP.IDsens.sensorsParams.labels{k}, label_to_min{l})
%             figure
%             J = myMAP.IDsens.sensorsParams.sizes{k};
%             I = py(k)+1 : py(k)+J;
%             colors = ['r', 'g', 'b'];
%             for j = 1 : J
%                 subplot(2, ceil(J/2), j)
%                 hold on;
%                 plot(data.time, data.y(I(j),:), [colors(mod(j,3)+1) '--'] , 'LineWidth', 1);
%                 plot(data.time, yMAP(I(j),:), [colors(mod(j,3)+1) , '.'], 'LineWidth', 2);
%                 
%                 title(strcat(strrep(myMAP.IDsens.sensorsParams.labels{k}, '_', '~'),num2str(j)));
%             end
%         end
%     end
% end
% 
% % wait
% pause;
% close all
% clc


%% Create the estimator and model...
%
% Create an estimator class, load the respective model from URDF file and
% set the robot state constant parameters

% Create estimator class
estimator = iDynTree.ExtWrenchesAndJointTorquesEstimator();

% Load model and sensors from the URDF file
estimator.loadModelAndSensorsFromFile('../models/iCubGenova02/iCubFull.urdf');

% Check if the model was correctly created by printing the model
estimator.model().toString()

%% Optimization
%

for part = 1 : length(jointsToCalibrate.parts)

    number_of_random_init = 5;
    subsetVec_size = round(data.nsamples*0.1);
    Dq0 = cell2mat(jointsToCalibrate.jointsInitOffsets(part))';
    
    % run minimisation for every random subset of data.
    % 1 subset <=> all measurements for a given timestamp <=>1 column index of
    % table `q_xxx`, `dq_xxx`, `ddq_xxx`, `y_xxx_acc`, ...
    for i = 1 : number_of_random_init
        
        % define a random subset: 10 % of the total set of instants
        subsetVec_idx = randsample(data.nsamples, subsetVec_size);
        subsetVec_idx = sort(subsetVec_idx);
        
        % Optimization options: we won't provide the gradient for now
        %
        % For FUNCTION 'fminunc'
        % Display: 'iter'
        % MaxFunEvals:
        % MaxIter:
        % TolFun:  1e-7
        % TolX: 0.1 (Encoders accuracy => 12 bits for 360 deg => 1 tick =
        % 0.087 deg ~ 0.1 deg)
        % FunValCheck: 'on'
        % ActiveConstrTol:
        % Algorithm: 'interior-point'
        % AlwaysHonorConstraints:
        % GradConstr:
        % GradObj:
        % InitTrustRegionRadius:
        % LargeScale:
        % ScaleProblem:
        % SubproblemAlgorithm:
        % UseParallel:
        % PlotFcns : {@optimplotx, @optimplotfval, @optimplotstepsize}
        %
        options = optimset('Algorithm','interior-point', ...
            'TolFun', 1e-7, 'TolX', 1e-1, 'FunValCheck', 'on', ...
            'Display', 'iter', 'PlotFcns', {@optimplotx, @optimplotfval, @optimplotstepsize});
        
        % optimize
        [optimalDq(:, i), fval(i), exitflag(i), output(i)] = fminunc(@(Dq) costFunctionSigma(Dq, part, jointsToCalibrate, ...
                                                                                             data, subsetVec_idx, estimator), ...
                                                                     Dq0, options);
        optimalDq(:, i) = mod(optimalDq(:, i)+pi, 2*pi)-pi;
    end
    
    optimalDq
    fval
    exitflag
    output

end


%%

% run('iCubSensTransforms.m');
% run('iCub.m');
% 
% %% Process raw sensor data and bring it in the desired reference frames
% acc_gain = 5.9855e-04;
% %acc_gain = 1.0;
% deg_to_rad = pi/180.0;
% gyro_gain = deg_to_rad*7.6274e-03;
% for l = 1 : length(label_to_plot)
%     for i = 1 : length(data.parts)
%         if strcmp(data.labels{i}, label_to_plot{l})
%             t    = ['time_' data.labels{i}];
%             ys   = ['ys_' data.labels{i}];
%             J = length(eval(data.index{i}));
%             if( strcmp(data.labels{i},'lh_imu') || ...
%                     strcmp(data.labels{i},'rh_imu') )
%                 eval(['data.ys_' data.labels{i} '(1:3,:) = ' ...
%                     'acc_gain*data.ys_' data.labels{i} '(1:3,:);']);
%                 eval(['data.ys_' data.labels{i} '(4:6,:) = ' ...
%                     'gyro_gain*data.ys_' data.labels{i} '(4:6,:);']);
%             end
%             if( strcmp(data.labels{i},'imu') )
%                 eval(['data.ys_' data.labels{i} '(4:6,:) = ' ...
%                     'deg_to_rad*data.ys_' data.labels{i} '(4:6,:);']);
%             end
%             if( strcmp(data.labels{i}(end-2:end),'acc') )
%                 eval(['data.ys_' data.labels{i} '(1:3,:) = ' ...
%                     'acc_gain*data.ys_' data.labels{i} '(1:3,:);']);
%                 eval(['data.ys_' data.labels{i} ' = ' ...
%                     sens.transform{i} '(1:3,1:3) * ' 'data.ys_' data.labels{i} ';']);
%                 strcat('correcting ',(data.labels{i}),' measures')
%                 
%             end
%             if( strcmp(data.labels{i}(end-2:end),'imu') )
%                 eval(['data.ys_' data.labels{i} ' = ' ...
%                     sens.transform{i} ' * ' 'data.ys_' data.labels{i} ';']);
%                 % account for the wrong offset present in the input data
%             end
%             if( strcmp(data.labels{i}(end-2:end),'fts') )
%                 eval(['data.ys_' data.labels{i} ' = -normalToStart(' ...
%                     sens.transform{i} ') * ' 'data.ys_' data.labels{i} ';']);
%             end
%         end
%     end
% end
% 
% fprintf('Processed raw sensors\n')
% 
% %% Build data.y anda data.Sy from adjusted ys_label
% data.y  = [];
% 
% % Add the null external forces fx = 0
% data.y  = [data.y; zeros(6*iCub_dmodel.NB, length(data.time))];
% % Add the d2q measurements
% data.y  = [data.y; data.d2q];
% 
% for i = 1 : length(sens.labels)
%     eval(['data.y  = [data.y ; data.ys_' sens.labels{i} '];']);
% end
% 
% %% Visulize results of optmization
% 
% % load the necessary transforms from URDF
% % this transforms are computed using the
% % computeURDFToDrakeTransforms script
% %computeURDFToDrakeTransforms;
% 
% dmodel  = iCub_dmodel;
% ymodel  = iCubSens(dmodel, sens);
% dmodel  = autoTreeStochastic(dmodel, 1e-7, 1e4);
% ymodel  = iCubSensStochastic(ymodel);
% 
% myModel = model(dmodel);
% mySens  = sensors(ymodel);
% myMAP  = MAP(myModel, mySens);
% 
% yMAP = zeros(size(data.y));
% for i = 1 : length(data.time)
%     myMAP     = myMAP.setState(data.q(:,i), data.dq(:,i));
%     myMAP     = myMAP.setY(data.y(:,i));
%     myMAP     = myMAP.solveID();
%     yMAP(:,i) = myMAP.simY(myMAP.d);
%     if mod(i-1,100) == 0
%         fprintf('Processing %d %% of the dataset\n', round(i/length(data.time)*100));
%     end
% end
% 
% label_to_min   = {'rl_fts','rf_fts', '11B1_acc', '11B2_acc', '11B3_acc', '11B4_acc', '11B5_acc', '11B7_acc', '11B8_acc', '11B9_acc', '11B10_acc', '11B11_acc', '11B13_acc', '11B12_acc'};
% joint_to_min   = {'r_hip_roll', 'r_hip_pitch', 'r_hip_yaw', 'r_ankle_roll', 'r_ankle_pitch', 'r_knee'};
% 
% index_to_min   = zeros(size(dmodel.jointname));
% for i = 1 : length(joint_to_min)
%     index_to_min = index_to_min | strcmp(dmodel.jointname, joint_to_min{i});
% end
% 
% 
% %% Plot overlapped plots
% py = [0; cumsum(cell2mat(myMAP.IDsens.sensorsParams.sizes))];
% for l = 1 : length(label_to_min)
%     for k = 1 : myMAP.IDsens.sensorsParams.ny
%         if strcmp(myMAP.IDsens.sensorsParams.labels{k}, label_to_min{l})
%             figure
%             J = myMAP.IDsens.sensorsParams.sizes{k};
%             I = py(k)+1 : py(k)+J;
%             colors = ['r', 'g', 'b'];
%             for j = 1 : J
%                 subplot(2, ceil(J/2), j)
%                 hold on;
%                 plot(data.time, data.y(I(j),:), [colors(mod(j,3)+1) '--'] , 'LineWidth', 1);
%                 plot(data.time, yMAP(I(j),:), [colors(mod(j,3)+1) , '.'], 'LineWidth', 2);
%                 
%                 title(strcat(strrep(myMAP.IDsens.sensorsParams.labels{k}, '_', '~'),num2str(j)));
%             end
%         end
%     end
% end
% 
% 
% %% MAP model
% set_to_map   = {'rl_fts', 'rf_fts', '11B1_acc', '11B2_acc', '11B3_acc', '11B4_acc', '11B5_acc', '11B7_acc', '11B8_acc', '11B9_acc', '11B10_acc', '11B11_acc', '11B13_acc', '11B12_acc'};
% 
% for r = 0 %:length(set_to_map)
%     
%     
%     label_to_map = set_to_map(1:r);
%     
%     % remove from sens the values not in label_to_map
%     index_to_map = zeros(size(label_to_map));
%     for k = 1 : length(sens.labels)
%         for l = 1 : length(label_to_map)
%             if strcmp(sens.labels{k}, label_to_map{l})
%                 index_to_map(l) = k;
%             end
%         end
%     end
%     sensReduced.parts = sens.parts(index_to_map);
%     sensReduced.labels = sens.labels(index_to_map);
%     sensReduced.ndof = sens.ndof(index_to_map);
%     sensReduced.type = sens.type(index_to_map);
%     sensReduced.transform = sens.transform(index_to_map);
%     
%     
%     run('iCub.m');
%     
%     % load the necessary transforms from URDF
%     % this transforms are computed using the
%     % computeURDFToDrakeTransforms script
%     %computeURDFToDrakeTransforms;
%     run('iCubSensTransforms.m');
%     
%     dmodel  = iCub_dmodel;
%     ymodel  = iCubSens(dmodel, sens);
%     dmodel  = autoTreeStochastic(dmodel, 1e-7, 1e4);
%     ymodel  = iCubSensStochastic(ymodel);
%     
%     myModel = model(dmodel);
%     mySens  = sensors(ymodel);
%     myMAP  = MAP(myModel, mySens);
%     
%     ymodel  = iCubSens(dmodel, sensReduced);
%     ymodel  = iCubSensStochastic(ymodel);
%     mySens  = sensors(ymodel);
%     myRMAP  = MAP(myModel, mySens);
%     


% for i = 1 : number_of_random_init
%     
%     % define a random subset
%     subset_to_min = ['11B12_acc', label_to_min(randsample(length(label_to_min), j-1))];
%     index_to_min  = zeros(size(dmodel.jointname));
%     for k = 1 : length(joint_to_min)
%         index_to_min = index_to_min | strcmp(dmodel.jointname, joint_to_min{k});
%     end
% 
%     dq0 = randn(sum(index_to_min),1)*0.5;
%     dt  = randsample(data.nsamples, round(data.nsamples*0.5)); %sample a 10% reduced set of time instants
%     dt = sort(dt);
%     op  = optimset('Display', 'iter', 'TolFun', 1e-7, 'Algorithm','interior-point');
%     % [dq(:, i, j), fval(i), exitflag, output, grad(:,i)] = fminunc(@(dq) costFunctionMAP(dq, dt, data, myMAP, myRMAP, subset_to_min, label_to_map, index_to_min), dq0, op);
%     [dq(:, i, j), fval(i), exitflag, output, grad(:,i)] = fminunc(@(dq) costFunctionID(dq, dt, data, myMAP, subset_to_min, index_to_min), dq0, op);
%     dq(:, i, j) = mod(dq(:, i, j)+pi, 2*pi)-pi;
% end
% 
% 
% std_dq{r+1,j} = std(dq(:, :, j)');
% std(dq(:, :, j)')
