L_GM = 1.3E3;       % [m]
invT_GM = 5.2E-3;   % [1/s]
E_GM = 6.3E-5;      % [unitless]

E_GM_total = L_GM*L_GM*L_GM*invT_GM*invT_GM*E_GM;

file = '/Users/jearly/Desktop/InternalWavesLatmix2011_128_128_64_lat31_all_floats.nc';
file = '/Users/jearly/Desktop/InternalWavesConstantN_256_256_128_lat31_unit_test_no_diffusivity.nc';

x = ncread(file, 'x');
y = ncread(file, 'y');
z = ncread(file, 'z');
t = ncread(file, 'time');
rho_bar = double(ncread(file, 'rho_bar'));
N2 = double(ncread(file, 'N2'));

iTime=1;
zeta3d = double(squeeze(ncread(file, 'zeta', [1 1 1 iTime], [length(y) length(x) length(z) 1], [1 1 1 1])));
rho3d = double(squeeze(ncread(file, 'rho', [1 1 1 iTime], [length(y) length(x) length(z) 1], [1 1 1 1])));
u3d = double(squeeze(ncread(file, 'u', [1 1 1 iTime], [length(y) length(x) length(z) 1], [1 1 1 1])));
v3d = double(squeeze(ncread(file, 'v', [1 1 1 iTime], [length(y) length(x) length(z) 1], [1 1 1 1])));


E_p = 0.5*trapz(z,N2.*squeeze(vmean(vmean(zeta3d.*zeta3d,1),2)));

E_k = 0.5*trapz(z,squeeze(vmean(vmean(u3d.*u3d+v3d.*v3d,1),2)));

potential_kinetic_ratio = E_p/E_k
GM_relative = (E_p+E_k)/E_GM_total

% Let's see how much the pycnocline varies with depth
[val,pycnocline_index]=max(N2);
zeta_pycnocline = reshape(zeta3d(:,:,pycnocline_index), length(x)*length(y),1);
std(zeta_pycnocline)

rhodamine_index = find(z<-32,1,'last');
zeta_rhodamine = reshape(zeta3d(:,:,rhodamine_index), length(x)*length(y),1);
std(zeta_rhodamine)

figure, hist(zeta_rhodamine)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Show fake 'glider' profiles
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%rho = rhoFromZeta(zeta3d,z,rho_bar);
rho = rho3d(1:5:end,1:5:end,:);
rho = reshape( rho, size(rho,1)*size(rho,2), size(rho,3));
sigma = rho-1000;
meanSigma = vmean(sigma,1);
stdSigma = std(sigma);

titleFontSize = 16;
axisFontSize = 12;
figure('Position', [200 200 800 1000])

subplot(1,2,1)
plot( sigma, z)
hold on
plot(meanSigma, z, 'black', 'LineWidth', 2)
plot(meanSigma+stdSigma, z, 'black', 'LineWidth', 1.5)
plot(meanSigma-stdSigma, z, 'black', 'LineWidth', 1.5)
xlabel('density (kg/m^3 - 1000) ', 'FontSize', axisFontSize)
ylabel('z (meters)', 'FontSize', axisFontSize)
xlim([24.4 30.3])
ylim([-100 0])
title('Density vs depth', 'FontSize', titleFontSize)

return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Check the frequency spectrum at a given point
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

u3d = double(squeeze(ncread(file, 'u', [1 1 20 1], [length(y) length(x) 1 length(t)], [1 1 1 1])));
v3d = double(squeeze(ncread(file, 'v', [1 1 20 1], [length(y) length(x) 1 length(t)], [1 1 1 1])));

f0 = ncreadatt(file, '/', 'f0');
dt = t(2)-t(1)

[M, N, K] = size(u3d);

% Compute a few 'mooring' time series
cv_mooring = zeros([length(t) 1]);
subsample = 16;
iMooring = 0;
for i=1:subsample:M
	for j=1:subsample:N
		iMooring = iMooring+1;
		cv_mooring(:,iMooring) = squeeze(u3d(i,j,:) + sqrt(-1)*v3d(i,j,:));
	end
end

[fn, sn] = powspec(dt,cv_mooring);
sn = vmean(sn,2);
negativeF = find(fn<0);
positiveF = find(fn>0);
if (length(negativeF) > length(positiveF))
	negativeF(1) = [];
end
s1sided = cat(1, sn(find(fn==0)), flipud(sn(negativeF))+sn(positiveF));
f1sided = fn(find(fn>=0));
figure, plot(fn, sn), ylog
hold on, plot(f1sided, s1sided, 'k')
plot(-f1sided, s1sided, 'k')


return;

fn = f1sided;
sn = s1sided;
% grab indices between the Coriolis and half the nyquist
fitIndices = find( fn > 1.5*f0/(2*pi) & fn < 0.4*1/(2*dt));
[P,S] = polyfit(log10(fn(fitIndices)), log10(sn(fitIndices)),1);
fit = 10^(P(2))*fn.^(P(1));
hold on
plot( fn(fitIndices), fit(fitIndices), 'r')
slope = P(1)

[psi,lambda]=sleptap(size(cv_mooring,1),3);
[fn,spp,snn,spn]=mspec(dt,cv_mooring,psi);
fn=fn/(2*pi);
figure, plot(fn, vmean(spp,2)), ylog
hold on, plot(fn, vmean(snn,2))
plot(fn,vmean(spp+snn,2))

sn = vmean(spp+snn,2);
% grab indices between the Coriolis and half the nyquist
fitIndices = find( fn > 1.5*f0/(2*pi) & fn < 0.4*1/(2*dt));
[P,S] = polyfit(log10(fn(fitIndices)), log10(sn(fitIndices)),1);
fit = 10^(P(2))*fn.^(P(1));
hold on
plot( fn(fitIndices), fit(fitIndices), 'r')
slope = P(1)


xindices = 1:2:length(x);
yindices = 1:2:length(y);
figure
iTime = 2;
quiver(x(xindices),y(yindices),u3d(xindices,yindices,iTime),v3d(xindices,yindices,iTime),0.8)
xlim([min(x) max(x)])
ylim([min(y) max(y)])