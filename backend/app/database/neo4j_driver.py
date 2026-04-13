from neo4j import GraphDatabase
from typing import Optional
from ..config import settings
import logging

logger = logging.getLogger(__name__)


class Neo4jDriver:
    """Singleton Neo4j database driver"""
    
    _instance: Optional['Neo4jDriver'] = None
    _driver: Optional[GraphDatabase.driver] = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Neo4jDriver, cls).__new__(cls)
            cls._instance._initialize()
        return cls._instance
    
    def _initialize(self):
        """Initialize Neo4j driver"""
        try:
            uri = self._normalize_neo4j_uri(settings.NEO4J_URI)
            self._driver = GraphDatabase.driver(
                uri,
                auth=(settings.NEO4J_USERNAME, settings.NEO4J_PASSWORD),
                max_connection_lifetime=3600,
                max_connection_pool_size=50,
                connection_acquisition_timeout=60
            )
            logger.info(f"Neo4j driver initialized successfully ({uri})")
        except Exception as e:
            logger.error(f"Failed to initialize Neo4j driver: {str(e)}", exc_info=True)
            self._driver = None

    @staticmethod
    def _normalize_neo4j_uri(raw_uri: str) -> str:
        """Normalize Neo4j URI to a driver-compatible value."""
        uri = (raw_uri or '').strip()
        if not uri:
            return 'bolt://localhost:7687'

        if '://' in uri:
            return uri

        host = uri.split(':')[0]
        if host.endswith('.databases.neo4j.io'):
            return f'neo4j+s://{host}'

        return f'bolt://{uri}'
    
    def get_session(self):
        """Get a new Neo4j session"""
        if self._driver is None:
            raise Exception("Neo4j driver not initialized")
        # For Aura (neo4j+s:// or neo4j+ssc://), don't specify database - use default
        if settings.NEO4J_URI.startswith(("neo4j+s://", "neo4j+ssc://")):
            return self._driver.session()
        return self._driver.session(database=settings.NEO4J_DATABASE)
    
    def close(self):
        """Close Neo4j driver"""
        if self._driver:
            self._driver.close()
    def verify_connectivity(self):
        """Verify database connectivity"""
        if self._driver is None:
            return False
            
        try:
            # Direct query test (works better than driver.verify_connectivity for Aura)
            session = None
            if settings.NEO4J_URI.startswith(("neo4j+s://", "neo4j+ssc://")):
                session = self._driver.session()
            else:
                session = self._driver.session(database=settings.NEO4J_DATABASE)
            
            with session:
                result = session.run("RETURN 1 AS num")
                record = result.single()
                if record and record["num"] == 1:
                    return True
                    
            return False
                
        except Exception as e:
            error_msg = str(e)
            logger.warning(f"Neo4j connection verification failed: {error_msg}")
            return False
    
    def execute_query(self, query: str, parameters: dict = None):
        """Execute a Cypher query"""
        with self.get_session() as session:
            result = session.run(query, parameters or {})
            return [record.data() for record in result]
    
    def execute_write(self, query: str, parameters: dict = None):
        """Execute a write transaction"""
        with self.get_session() as session:
            def transaction_function(tx):
                result = tx.run(query, parameters or {})
                return [record.data() for record in result]
            
            return session.execute_write(transaction_function)
    
    def execute_read(self, query: str, parameters: dict = None):
        """Execute a read transaction"""
        with self.get_session() as session:
            def transaction_function(tx):
                result = tx.run(query, parameters or {})
                return [record.data() for record in result]
            
            return session.execute_read(transaction_function)


# Create singleton instance
neo4j_driver = Neo4jDriver()


def get_neo4j_driver() -> Neo4jDriver:
    """Get Neo4j driver instance"""
    return neo4j_driver
