Here’s the updated `README.md` with the correct Git URLs, author, and company information:

---

# **etops - EgypTeam DevOps SDK**  
**etops** is a CLI tool for orchestrating Kubernetes development and runtime environments for EgypTeam applications. It manages environments and services through simple bash commands and YAML descriptors.

**Author**: Pedro Ferreira  
**Company**: EgypTeam Intelligent Solutions  

---

## **🚀 Features**  
- **Environment Management**: Create, start, stop, or destroy Kubernetes environments.  
- **Service Orchestration**: Deploy services using namespace-based descriptors.  
- **Fast Recovery**: Stop/start environments without full recreation.  

---

## **📦 Installation**  
### **Prerequisites**  
- Bash 4.0+  
- Kubernetes (`kubectl` configured)  
- Git (for submodule setup)  

### **Setup**  
1. Clone the repository:  
   ```bash
   git clone git@github.com:EgypTeam/etops.git
   ```  
   *(Web URL: [https://github.com/EgypTeam/etops](https://github.com/EgypTeam/etops))*  

2. **(Internal Users Only)** Initialize private submodules (descriptors/HAProxy):  
   ```bash
   git submodule update --init --recursive
   ```  

---

## **🛠️ Commands**  

### **Environment Management**  
| Command          | Description                                                                 |  
|------------------|-----------------------------------------------------------------------------|  
| `etops create`   | Creates a Kubernetes environment.                                           |  
| `etops start`    | Starts the environment (creates if missing).                                |  
| `etops stop`     | Stops the environment (preserves state for restart).                        |  
| `etops destroy`  | Deletes the environment (use `create`/`start` to rebuild).                  |  

### **Service Management**  
| Command                          | Descriptor Path                                          |  
|----------------------------------|---------------------------------------------------------|  
| `etops create <servicename>`     | `descriptors/default/<servicename>.yaml`                |  
| `etops create <ns>/<servicename>`| `descriptors/<namespace>/<servicename>.yaml`            |  
| `etops destroy <servicename>`    | `descriptors/default/<servicename>.yaml`                |  
| `etops start <ns>/<servicename>` | `descriptors/<namespace>/<servicename>.yaml`            |  

---

## **📂 Repository Structure**  
```plaintext
etops/
├── bin/                      # Main CLI scripts
├── descriptors/              # Service descriptors (submodule for internal)
│   ├── default/              # Default namespace descriptors
│   └── <namespace>/          # Namespace-specific descriptors
├── haproxy/                  # HAProxy configs (submodule for internal)
├── lib/                      # Shared libraries
└── samples/                  # Example files for public users
```

---

## **🔒 Access Control**  
- **Public Users**: Get sample descriptors in `descriptors/*.sample.yaml`.  
- **Internal Users**: Access real configs via private submodules.  

---

## **💡 Examples**  
### **1. Create a Service**  
```bash
etops create default/nginx  # Uses descriptors/default/nginx.yaml
```  
### **2. Stop an Environment**  
```bash
etops stop
```  

---

## **⚠️ Notes**  
- **Performance**: `stop`/`start` is faster than `destroy`/`create`.  
- **Safety**: `destroy` removes all resources irreversibly.  

---

## **🛠️ Development**  
To contribute:  
1. Fork the repo.  
2. Add tests for new features in `tests/`.  
3. Submit a PR to `git@github.com:EgypTeam/etops.git`.  

---

## **📜 License**  
MIT © [EgypTeam Intelligent Solutions](https://github.com/EgypTeam).  

--- 

### **📞 Contact**  
For issues or questions, contact:  
- **Pedro Ferreira**  
- GitHub: [@pedroferreira](https://github.com/pedroferreira) *(example)*  
- Email: [pedro.ferreira@egypteam.com](mailto:pedro.ferreira@egypteam.com) *(example)*  

---

This version includes:  
1. Correct Git URLs (SSH + web)  
2. Author and company details  
3. Consistent formatting for EgypTeam branding  
4. Placeholder contact info (update as needed)  

Let me know if you'd like to add CI/CD badges or contributor guidelines!