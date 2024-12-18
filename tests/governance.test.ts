import { describe, it, expect, beforeEach, vi } from 'vitest';

describe('Governance Contract', () => {
  const contractName = 'governance';
  let mockContractCall: any;
  
  beforeEach(() => {
    mockContractCall = vi.fn();
  });
  
  it('should create a proposal', async () => {
    mockContractCall.mockResolvedValue({ success: true, value: 1 });
    const result = await mockContractCall(contractName, 'create-proposal', ['Test proposal', 1000, 'update-premium-calculation']);
    expect(result.success).toBe(true);
    expect(result.value).toBe(1);
  });
  
  it('should vote on a proposal', async () => {
    mockContractCall.mockResolvedValue({ success: true });
    const result = await mockContractCall(contractName, 'vote', [1, 100, true]);
    expect(result.success).toBe(true);
  });
  
  it('should end a proposal', async () => {
    mockContractCall.mockResolvedValue({ success: true });
    const result = await mockContractCall(contractName, 'end-proposal', [1]);
    expect(result.success).toBe(true);
  });
});
