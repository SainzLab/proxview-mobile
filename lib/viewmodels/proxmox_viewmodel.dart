import 'package:flutter/foundation.dart';
import '../models/proxmox_model.dart';
import '../services/api_service.dart';

class ProxmoxViewModel extends ChangeNotifier {
  final ProxViewApiService _apiService;

  List<ProxmoxServerModel> _servers = [];
  ProxmoxServerModel? _selectedServer;
  List<ProxmoxNodeStatusModel> _nodeStatuses = [];
  ProxmoxResourcesBundle _resources = const ProxmoxResourcesBundle(
    vms: [],
    lxcs: [],
    storages: [],
  );

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  ProxmoxViewModel(this._apiService);

  List<ProxmoxServerModel> get servers => _servers;
  ProxmoxServerModel? get selectedServer => _selectedServer;
  List<ProxmoxNodeStatusModel> get nodeStatuses => _nodeStatuses;
  ProxmoxResourcesBundle get resources => _resources;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  List<ProxmoxNodeStatusModel> get filteredNodes {
    if (_searchQuery.trim().isEmpty) return _nodeStatuses;
    final q = _searchQuery.trim().toLowerCase();
    return _nodeStatuses
        .where((n) =>
            n.nodeName.toLowerCase().contains(q) ||
            n.status.toLowerCase().contains(q) ||
            n.cpuModel.toLowerCase().contains(q) ||
            n.loadAverage.toLowerCase().contains(q) ||
            n.uptime.toLowerCase().contains(q))
        .toList();
  }

  List<ProxmoxGuestModel> get filteredVms {
    if (_searchQuery.trim().isEmpty) return _resources.vms;
    final q = _searchQuery.trim().toLowerCase();
    return _resources.vms
        .where((vm) =>
            vm.name.toLowerCase().contains(q) ||
            vm.vmid.toString().contains(q) ||
            vm.node.toLowerCase().contains(q) ||
            vm.status.toLowerCase().contains(q) ||
            vm.type.toLowerCase().contains(q))
        .toList();
  }

  List<ProxmoxGuestModel> get filteredLxcs {
    if (_searchQuery.trim().isEmpty) return _resources.lxcs;
    final q = _searchQuery.trim().toLowerCase();
    return _resources.lxcs
        .where((lxc) =>
            lxc.name.toLowerCase().contains(q) ||
            lxc.vmid.toString().contains(q) ||
            lxc.node.toLowerCase().contains(q) ||
            lxc.status.toLowerCase().contains(q) ||
            lxc.type.toLowerCase().contains(q))
        .toList();
  }

  List<ProxmoxStorageModel> get filteredStorages {
    if (_searchQuery.trim().isEmpty) return _resources.storages;
    final q = _searchQuery.trim().toLowerCase();
    return _resources.storages
        .where((st) =>
            st.storage.toLowerCase().contains(q) ||
            st.node.toLowerCase().contains(q) ||
            st.type.toLowerCase().contains(q) ||
            st.used.toLowerCase().contains(q) ||
            st.total.toLowerCase().contains(q))
        .toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchProxmoxData({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final rawServers = await _apiService.getProxmoxServers();
      // Urutkan daftar server secara deterministik berdasarkan id
      _servers = List<ProxmoxServerModel>.from(rawServers)
        ..sort((a, b) => a.id.compareTo(b.id));

      if (_servers.isEmpty) {
        _selectedServer = null;
        _nodeStatuses = [];
        _resources = const ProxmoxResourcesBundle(vms: [], lxcs: [], storages: []);
      } else {
        if (_selectedServer == null ||
            !_servers.any((s) => s.id == _selectedServer!.id)) {
          _selectedServer = _servers.first;
        } else {
          _selectedServer = _servers.firstWhere((s) => s.id == _selectedServer!.id);
        }
        await _fetchSelectedServerDetails(_selectedServer!.id);
      }
      _errorMessage = null;
    } catch (e) {
      if (showLoading || _servers.isEmpty) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectServer(ProxmoxServerModel server) async {
    if (_selectedServer?.id == server.id) return;
    _selectedServer = server;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchSelectedServerDetails(server.id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSelectedServerDetails(int serverId) async {
    final results = await Future.wait([
      _apiService.getProxmoxNodeStatus(serverId),
      _apiService.getProxmoxResources(serverId),
    ]);
    final rawNodes = results[0] as List<ProxmoxNodeStatusModel>;
    final rawResources = results[1] as ProxmoxResourcesBundle;

    // 1. Urutkan Nodes secara fix berdasarkan nodeName alfabetis
    _nodeStatuses = List<ProxmoxNodeStatusModel>.from(rawNodes)
      ..sort((a, b) => a.nodeName.toLowerCase().compareTo(b.nodeName.toLowerCase()));

    // 2. Urutkan VMs secara fix berdasarkan VMID numerik (100, 101, 102...)
    final sortedVms = List<ProxmoxGuestModel>.from(rawResources.vms)
      ..sort((a, b) => a.vmid.compareTo(b.vmid));

    // 3. Urutkan LXCs secara fix berdasarkan VMID numerik (200, 201...)
    final sortedLxcs = List<ProxmoxGuestModel>.from(rawResources.lxcs)
      ..sort((a, b) => a.vmid.compareTo(b.vmid));

    // 4. Urutkan Storages secara fix berdasarkan nama storage, lalu nama node
    final sortedStorages = List<ProxmoxStorageModel>.from(rawResources.storages)
      ..sort((a, b) {
        final cmp = a.storage.toLowerCase().compareTo(b.storage.toLowerCase());
        if (cmp != 0) return cmp;
        return a.node.toLowerCase().compareTo(b.node.toLowerCase());
      });

    _resources = ProxmoxResourcesBundle(
      vms: sortedVms,
      lxcs: sortedLxcs,
      storages: sortedStorages,
    );
  }
}
